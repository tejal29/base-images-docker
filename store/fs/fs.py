# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""This tool build tar files from a list of inputs."""

from contextlib import contextmanager
from datetime import datetime
import os
import subprocess
import sys
from third_party.py import gflags

gflags.DEFINE_string('file', None, 'The absolute path to file')
gflags.DEFINE_string('local_fs_file', None, 'The absolute path to local file system file')
gflags.DEFINE_string('fs_root', None, 'The absolute path to local file system root')
gflags.DEFINE_string('method', 'get', 'FileSystemStore method either init, get, put')
gflags.DEFINE_string('operation_status', None, 'The File to write the status operation to')


gflags.MarkFlagAsRequired('file')
gflags.MarkFlagAsRequired('local_fs_file')
gflags.MarkFlagAsRequired('fs_root')
#gflags.MarkFlagAsRequired('operation_status')


FLAGS = gflags.FLAGS

class LocalFSStore(object):
  """A class to fetch or commit file in local File System
     TODO: (tejaldesai) Add ability to do this from remote git"""

  STORE_METADATA_FILE = '.store'


  class LocalFSStoreError(Exception):
    def __init__(self, operation, message):
      self.method = operation
      self.message = message

    def __str__(self):
      return 'Method {0} failed due to {1}'.format(self.method, self.message)


  def __init__(self, fs_root, local_fs_file, file, operation_status, method):
     self.fs_root = fs_root
     self.file = file
     self.local_fs_file = local_fs_file
     self.operation_stats = operation_status
     self.method = method

  def __enter__(self):
     if self.operation_stats:
       self.status_file = open(self.operation_stats, 'w')
       self.STATUS_CODE = 0
     return self

  def __exit__(self, t, v, traceback):
    if self.operation_stats:
      self.status_file.write("{0}".format(self.STATUS_CODE))
      print(self.status_file)
      self.status_file.close()

  @contextmanager
  def ch_root(self):
     current_dir = os.getcwd()
     try:
       os.chdir(self.fs_root)
       yield
     finally:
       os.chdir(current_dir)

  @contextmanager
  def _execute(self, commands):
    try:
     for command in commands:
       subprocess.check_output(command)
    except subprocess.CalledProcessError as e:
      self.STATUS_CODE = e.returncode
      #raise LocalFSStore.LocalFSStoreError(self.method, e)

  def init(self):
    "Create the local file system store if it does not exists"
    if self._store_exists():
      return
    self._execute(commands = [['mkdir', '-p', self.fs_root]])
    with self.ch_root():
      with open(LocalFSStore.STORE_METADATA_FILE, 'w') as f:
        f.write('Local Store Initialized at %s UTC' % str(datetime.utcnow()))


  def _store_exists(self):
    return os.path.exists(self.fs_root)

  def get(self):
    """Get file and copy it to bazel workspace"""
    if not self._store_exists():
       return
    with self.ch_root():
       self._execute(commands = [
           ['ls', self.local_fs_file],
           ['cp', self.local_fs_file, self.file]
       ])
       print("getting")

  def put(self):
    """Put file from Bazel workspace to local file system"""
    with self.ch_root():
      self._execute(commands = [
          ['cp', self.file, self.local_fs_file,]
      ])

def main(unused_argv):
  with LocalFSStore(fs_root=FLAGS.fs_root,
                    file=FLAGS.file,
                    local_fs_file=FLAGS.local_fs_file,
                    operation_status=FLAGS.operation_status,
                    method = FLAGS.method) as fs_store:
    if FLAGS.method == "get":
       fs_store.get()
    elif FLAGS.method == "put":
       fs_store.put()
    elif FLAGS.method == "init":
       fs_store.init()
    else:
      fs_store.STATUS_CODE = 1
      raise LocalFSStore.LocalFSStoreError(FLAGS.method, "Method not found")

if __name__ == '__main__':
  print(sys.argv)
  main(FLAGS(sys.argv))
