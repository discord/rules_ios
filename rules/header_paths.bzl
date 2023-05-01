load("@bazel_skylib//lib:paths.bzl", "paths")

def _stringify_mapping(headers_mapping):
    """
    Convert a mapping of {Target: string} to a mapping of {string:string}

    - Target is a target pointing to a single source file
    - the value in `headers_mapping` is the path within Headers/PrivateHeaders to use
      for the file.
    """
    ret = {}
    for (t, dest) in headers_mapping.items():
        files = t.files.to_list()
        if len(files) != 1:
            fail("{} should be a single file".format(t))
        f = files[0]
        if not f.is_source:
            fail("{} should be a single source file, not a generated file".format(f))
        ret[f.owner.name] = dest
    return ret

def _get_mapped_path(hdr, headers_mapping):
    """
    Get the relative destination path for a File

    This will return the value of mapping, or the basename of the file if no
    mapping exists or if `hdr` is not a source file.
    """
    if hdr.is_source:
        return headers_mapping.get(hdr.owner.name, hdr.basename)
    else:
        return hdr.basename

def _get_string_mapped_path(hdr, headers_mapping):
    return headers_mapping.get(hdr, paths.basename(hdr))

def _mapped_without_prefix(files, prefix):
    """
    Convert a list of source files to a mapping of those files -> paths with
    `prefix` removed
    """
    ret = {}
    for file in files:
        if file.startswith(prefix):
            ret[file] = file[len(prefix):]
        else:
            fail("File `{}` does not start with prefix `{}`".format(file, prefix))
    return ret

header_paths = struct(
    stringify_mapping = _stringify_mapping,
    get_mapped_path = _get_mapped_path,
    get_string_mapped_path = _get_string_mapped_path,
)
