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

load("//package_managers:download_pkgs.bzl", "download_pkgs")
load("//package_managers/apt_get:apt_get.bzl", "generate_apt_get")
load("//package_managers:install_pkgs.bzl", "install_pkgs")


def _impl(ctx):
  print(dir(ctx.attr.get))
  ctx.actions.write(
      output = ctx.outputs.executable,
      content = "echo {0}".format(ctx.attr.get.files.to_list()[0].path),
      is_executable = True, 
  )

def _get_impl(ctx):
    store = ctx.attr.store[store_provider]
#    dest_artifact = ctx.actions.declare_file("{0}.tar".format(ctx.attr.name))

    get_cmd = ' '.join(store.get_cmd_args).replace("%GET", "{date}/packages.tar".format(date=ctx.attr.date)).replace("%DEST", ctx.outputs.artifact.path)
    ctx.actions.run(
        outputs = [ctx.outputs.artifact, ], 
        executable = ctx.executable.store,
        arguments= get_cmd.split(' '),
        use_default_shell_env=True,
        mnemonic="GetArtifact"
    )
    return struct(
        runfiles = ctx.runfiles(files = ctx.attr.store.default_runfiles.files.to_list()),
        files = depset([ctx.outputs.artifact])
    )

bootstrap_image = rule(
    attrs = {
        "image_tar": attr.label(
            default = Label("//ubuntu:ubuntu_16_0_4_vanilla.tar"),
            allow_files = True,
            single_file = True,
        ),
       "download_pkgs": attr.label(
            executable = True,
            cfg = "target",
            allow_files = True,
            single_file = True,
        ),
        "install_pkgs":attr.label(
            cfg = "target",
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
       "get": attr.label(
           cfg = "target",
           allow_files = True,
#           executable = True,
       ), 
       # TODO: (tejaldesai) Add this in
       # "additional_repos": attr.string_list(),
    },
    executable = True,
    implementation = _impl,
)


_get_artifact_from_store = rule(
   attrs = {
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
#    executable = True, 
    implementation = _get_impl,
    outputs = {
      "artifact": "%{name}.tar",
    }
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

def bootstrap_image_macro(name, image_tar, package_manager_generator, store, date, output_image_name, additional_repos=[]):
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

  #tars = []
  #if additional_repos:
  #  repo_name="{0}_repos".format(name)
  #  generate_additional_repos(
  #      name = repo_name,
  #      repos = additional_repos
  # )
  #  tars.append("%s.tar" % repo_name)


  #img_target_name = "{0}_build".format(name)
  download_pkgs(
       name = "{0}_download".format(name),
       package_manager_generator = package_manager_generator,
       image_tar = image_tar,
  )
#  install_package_manager = 
  install_pkgs(
      name = "{0}_install".format(name),
      image_tar = image_tar,
      output_image_name = output_image_name,
      package_manager_generator = package_manager_generator,
  )
  _get_artifact_from_store(
     name = "{0}_get".format(name),
     store = store,
     date = date,
   )

  bootstrap_image(
      name = "{0}_boot".format(name),
      image_tar = image_tar,
      download_pkgs = ":{0}_download".format(name),
      install_pkgs = ":{0}_install".format(name),
      store = store,
      get = ":{0}_get".format(name)
  )
