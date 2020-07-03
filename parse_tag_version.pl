#!/usr/bin/perl
#
# Part of https://github.com/misje/cmake-git-version-tracking
#
# If a project uses git tags and semantic versioning, tags can be used to
# automatically set the version number in the project. The following regex
# parses the output of "git describe". Example tags:
#
# v1.2.3
# v1.2
# 1.2.3
# 1.2.3-4
# 2f7c290
# v2.4.0~rc1-3
# v2.4.0~rc1-3-104-gffba103
#
# The various parts of the version string are captures and printed as
# key–value pairs. Missing parts are not printed unless they are integers, in
# which case they are set to -1.

use warnings;
use strict;
use utf8;
    
chomp(my $gitDescription = qx(git describe --always --dirty));
#$gitDescription = join ' ', @ARGV;

unless ($gitDescription =~ /
\A
(?:
v?                                          # Optional "version v"
(?<full_extra>                              # Capture everything before deb revision
(?<full>                                    # ↑, except the "extra part"
(?<major>\d+)                               # Major
\.                                          # Period separator
(?<minor>\d+)                               # Minor
(?:\.(?<patch>\d+))?                        # Optional period separator and patch
)
(?<extra>[^-]+)?                            # Any text other than "-"
)
(?:-(?<revision>\d+)(?!\d*-g[0-9a-f]{4,}))? # Optional Debian revision
(?:-(?<commits>\d+)                         # Optional commit count
-g(?<sha>[0-9a-f]{4,}))?                    # Optinal git SHA hash
|                                           # … or
(?<sha>[0-9a-f]{4,})                        # Just the git SHA hash
)(?:-dirty)?
\Z
/x) {
	die "The git tag '$gitDescription' does not appear to be a version string\n";
}

# Print matched group by name, uppercase, prefixed by GIT_TAG_VERSION_:
print "GIT_TAG_VERSION_", uc $_, "=$+{$_}\n" for keys %+;
# If major and minor, print "major.minor(.patch)", otherwise sha:
print "GIT_TAG_VERSION_ANY=", (exists $+{'sha'} ? $+{'sha'} : $+{'full'}), "\n";
# Assign -1 to integer variables that were not matched:
foreach (qw(major minor patch revision commits)) {
    print "GIT_TAG_VERSION_", uc $_, "=-1\n" if not exists $+{$_};
}
# Create a binary variable for dirtyness:
print "GIT_TAG_VERSION_DIRTY=", $gitDescription =~ /-dirty\Z/ ? 1 : 0, "\n";
