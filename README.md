# Embed Git metadata in C/C++ project

This project is loosely based on [Andrew Hardin's work][1]. Check the project's
README for details. This fork differs in the following ways:

- Most of the logic, including the state using a hash of all the variables, is
  removed. I could not get the project to rebuild when needed, for instance
  when the input file was modified or a corresponding header file. This
  implementation simply runs `configure_file` on each invocation, which doesn't
  result in a modified output file unless the substitution variables change.
- A completely different approach has been taken to the default variables.
  Personally I have never had a need for commit details like author, e-mail or
  subject. Instead of using `git status`, `git describe` is used to parse the
  current or latest _git tag_. The tag is expected to follow semantic
  versioning and its individual version numbers are extracted into
  corresponding variables. As a fallback the shortened SHA is used.

Due to the limited regular expression engine in CMake (why do they implement
their own?) Perl is used to parse the output of git. Hence **perl** is needed.

## Tag format

- An optional "v"
- Major version number
- Minor version number
- Optional patch version number
- Optional extra characters other than "-"
- Optional deb revision number

### Examples:

- v1.2.3
- v1.2
- 0.1.0
- 0.1
- v2.4.0+rc1-3
- 5.0.0alpha-1

In the examples above the last number after the hyphen, if present, is the deb
revision. "+rc1" and "alpha" is referred to as "extra" in the following
sections.

## Variables

`git describe` provides the following information if HEAD is not the same as
the last tag:

- Number of commits since last tag
- The SHA of the last commit

With `--dirty` the command also outputs whether working tree is "dirty". All
three fields are captured, if present, into variables.

Variables have a default value of either an empty string or the integer -1.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| GIT\_TAG\_VERSION\_FULL | string | | major.minor(.patch) |
| GIT\_TAG\_VERSION\_FULL\_EXTRA | string | | As above but with any additional characters before deb revision, or empty |
| GIT\_TAG\_VERSION\_MAJOR | int | -1 | Major version number from tag |
| GIT\_TAG\_VERSION\_MINOR | int | -1 | Minor version number from tag |
| GIT\_TAG\_VERSION\_PATCH | int | -1 | Patch version number from tag |
| GIT\_TAG\_VERSION\_EXTRA | string | | Any text between sem.ver. and deb revision number |
| GIT\_TAG\_VERSION\_REVISION | int | -1 | deb revision number |
| GIT\_TAG\_VERSION\_COMMITS | int | -1 | Number of commits since last tag |
| GIT\_TAG\_VERSION\_SHA | string | | SHA of last commit or empty if last commit is a tag |
| GIT\_TAG\_VERSION\_DIRTY | int | | 1 if working tree is dirty, otherwise 0 |
| GIT\_TAG\_VERSION\_ANY | string | | If current commit is a tag, major.min(.patch), otherwise SHA |

## Usage

Look at the [original project][1] for examples. This version is used in a
similar way, except it doesn't make sense to use unless tagged version numbers
are used.

## Acknowledgments 

I'd like to thank Andrew Hardin for his work. The original project wasn't a
perfect fit for my use case, but I found it very helpful. I have published my
heavily modified version in case is it useful for anyone else.

[1]: https://github.com/andrew-hardin/cmake-git-version-tracking
