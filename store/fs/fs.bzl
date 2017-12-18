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
    tool_path = ctx.expand_location("$(location //{0}:{1})".format(ctx.attr._tool.label.package, ctx.attr._tool.label.name))
    args = "--fs_root {fs_root}".format(fs_root = ctx.attr.fs_root)

    fs_provider = store_provider(
        tool =  tool_path,
        get_cmd_args = [args, '--method get',  '--local_fs_file %GET', '--file %DEST'],
        put_cmd_args = '--method put {0} --local_fs_file %PUT --file %SRC'.format(args),
    )

    runfiles = ctx.runfiles(collect_default = True, 
                            files = ctx.attr._tool.default_runfiles.files.to_list() + [ctx.outputs.executable])
    print(runfiles)
#    ctx.file_action(ctx.outputs.executable,
#                    "{tool_path} {args}".format(tool_path=tool_path,
#                                                              args = args),
#                    executable=True)

    ctx.actions.run_shell(
        outputs = [ctx.outputs.executable,],
        inputs = [ctx.executable._tool],
        command = "cp %s %s" %(ctx.executable._tool.path, ctx.outputs.executable.path)
    )
    default_provider = DefaultInfo(files = depset([ctx.outputs.executable]),
                                   default_runfiles = runfiles,
                                   )

    return struct(
        #files = depset([ctx.executable._tool]),
        #runfiles = runfiles,
        providers = [fs_provider, default_provider],
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
        ),
        "deps": attr.label_list(
             default = [Label("//store/fs:fs")],
             allow_files = True,
        )
    },
    executable = True,
    implementation = _impl,
)
