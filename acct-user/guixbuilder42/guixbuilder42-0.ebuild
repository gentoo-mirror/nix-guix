# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# #===------------------------------------------------===#
# |This file is auto-generated by generate-acct-user.bash|
# #===------------------------------------------------===#
EAPI=8
inherit acct-user
DESCRIPTION="Builder user for guix-daemon from sys-apps/guix"
ACCT_USER_ID=31042
ACCT_USER_GROUPS=( guixbuild kvm )
acct-user_add_deps
