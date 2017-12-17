#Copyright 2017 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("//store:store_provider.bzl", "store_provider")

def _impl(ctx):
  args = "--fs_root {fs_root} ".format(fs_root = ctx.attr.fs_root)

  fs_provider = store_provider(
    tool = ctx.executable._tool,
    get_cmd = '--method get {0} --local_fs_file %GET --file %DEST'.format(args),
    put_cmd = '--method put {0} --local_fs_file %PUT --file %SRC'.format(args),
  )

#  runfiles_dir = ctx.actions.declare_directory("{0}.runfiles".format(ctx.attr._tool.label.name), sibling=ctx.executable._tool)
#  ctx.actions.run_shell(
#      inputs=ctx.attr._tool.files.to_list(),
#      outputs=[runfiles_dir],
#      command = "cp  %s %s" %(ctx.attr._tool.files.to_list()[0].path, runfiles_dir.path)
#  )
  print(runfiles_dir.path)
#  print(ctx.attr._tool.default_runfiles.files)
  runfiles = ctx.runfiles(collect_default = True, files = ctx.attr._tool.default_runfiles.files.to_list())
#  print(depset([ctx.executable._tool]) + ctx.attr._tool.files + ctx.attr._tool.default_runfiles.files.to_list())

  return struct(
      files = depset([ctx.executable._tool]) + ctx.attr._tool.files + ctx.attr._tool.default_runfiles.files.to_list(),
      runfiles = runfiles,
      providers = [fs_provider],
  )

fs_store = rule(
    attrs = {
        "fs_root": attr.string(
            doc="Local Git root directory",
            mandatory = True,
        ),
        "_tool": attr.label(
             default = Label("//store/fs:fs"),
             cfg = "host",
             executable = True,
             allow_files = True,
        )
    },
    implementation = _impl,
)
