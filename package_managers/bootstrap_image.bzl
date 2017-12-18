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

"""Rule for bootstrapping an image from using download_pkgs and install_pkgs """

#load("//package_managers:download_pkgs.bzl", "download_pkgs")
#load("//package_managers:install_pkgs.bzl", "install_pkgs")
load("//package_managers:package_manager_provider.bzl", "package_manager_provider")
load("//store:store_provider.bzl", "store_provider")
load("@io_bazel_rules_docker//docker:docker.bzl", "docker_build")

def _impl(ctx):
    package_manager = ctx.attr.package_manager_generator[package_manager_provider]
    store = ctx.attr.store[store_provider]
    dest_artifact = ctx.actions.declare_file("{0}.tar".format(ctx.attr.name),
                                             sibling=ctx.outputs.executable)
    status_file = ctx.actions.declare_file("{0}_get_status".format(ctx.attr.name))

    get_cmd = ' '.join(store.get_cmd_args).replace("%GET", "{date}/packages.tar".format(date=ctx.attr.date)).replace("%DEST", dest_artifact.path)
    ctx.action(
        outputs = [ctx.outputs.executable, dest_artifact, status_file],
        executable = ctx.executable.store,
        arguments= get_cmd.split(' ') + [ '--operation_status', status_file.path],
        use_default_shell_env=True,
        mnemonic="GetArtifact"
    )
    ctx.
    return struct(
        runfiles = ctx.runfiles(files = [ctx.file.image_tar,] + ctx.attr.store.default_runfiles.files.to_list()),
        files = depset([ctx.outputs.executable])
    )

bootstrap_image = rule(
    attrs = {
        "image_tar": attr.label(
            default = Label("//ubuntu:ubuntu_16_0_4_vanilla.tar"),
            allow_files = True,
            single_file = True,
        ),
        "package_manager_generator": attr.label(
            default = Label("//package_managers/apt_get:default_docker_packages"),
            executable = True,
            cfg = "target",
            allow_files = True,
            single_file = True,
            providers = [package_manager_provider],
        ),
       "store": attr.label(
           cfg = "target",
           allow_files = True,
           providers = [store_provider],
           executable = True,
       ),
       "date": attr.string(),
       # TODO: (tejaldesai) Add this in
       # "additional_repos": attr.string_list(),
    },
    executable = True,
    implementation = _impl,
)

"""Bootstrap images with packages from package manager or given location.

This rule builds an image with packages either by downloading packages from
package manager or given location.

Args:
  name: A unique name for this rule.
  image_tar: The image tar for the container used to download packages.
  package_manager_genrator: A target which generates a script using
       package management tool e.g apt-get, dpkg to downloads packages.
  store: A target to store the downloaded packages or retrieve previously downloaded packages.
  additional_repos: list of additional debian package repos to use, in sources.list format
"""

def bootstrap_image_macro(name, image_tar, package_manager_generator, store, date, additional_repos=[]):
  """Downloads packages within a container
  This rule creates a script to download packages within a container.
  The script bunldes all the packages in a tarball.
  Args:
    name: A unique name for this rule.
    image_tar: The image tar for the container used to download packages.
    package_manager_genrator: A target which generates a script using
      package management tool e.g apt-get, dpkg to downloads packages.
    packages: list of packages to download. e.g. ['curl', 'netbase']
    additional_repos: list of additional debian package repos to use, in sources.list format
  """

  # Check if packages.tar file exists in the store defines.
  store()
  
  tars = []
  if additional_repos:
    repo_name="{0}_repos".format(name)
    generate_additional_repos(
        name = repo_name,
        repos = additional_repos
   )
    tars.append("%s.tar" % repo_name)


  img_target_name = "{0}_build".format(name)
  download_pkgs(
       name = "{0}".format(name),
       package_manager_generator = package_manager_generator,
       image_tar = ":{0}.tar".format(img_target_name),
  )
