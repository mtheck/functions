#!/usr/bin/env bash

t_usage() {
	cat <<END
Execute test files (*.test) in current directory.

Usage:
  $0 [options] [<id> ...]

Options:
  -c <INTEGER>
    Number of test iterations (1)
  -v
    Verbose output
  -h
    Display this help
END
	exit 2
}

function t_error { t_log Error: "$@"; exit 1; }

function t_log { echo ">>> TEST $*"; } >&2

function t_fail { 
	local loc=${BASH_SOURCE[1]}@$BASH_LINENO

	[[ -t 1 ]] && loc=$'\e[4m'$loc$'\e[0m'

	t_log "$loc:$(sed -n ${BASH_LINENO}p "${BASH_SOURCE[1]}")"

	exit 1
}

function t_cmp {
	[[ $# -eq 2 ]] || return 2

	declare -p "$@" &>/dev/null || return 2

	[[ ${!1@a} == ${!2@a} ]] || return 1
	
	if [[ ${!1@a} == *[aA]* ]]; then
		local __i__ __k__ __v1__ __v2__ __ks1__=() __ks2__=()

		eval __v1__='${#'$1'[@]}' __v2__='${#'$2'[@]}'

		[[ $__v1__ -eq $__v2__ ]] || return 1

		eval __ks1__='("${!'$1'[@]}")' __ks2__='("${!'$2'[@]}")'

		for __k__ in "${__ks1__[@]}"; do
			for ((__i__=${#__ks2__[@]}-1; __i__>=0; __i__--)); do
				[[ $__k__ == "${__ks2__[$__i__]}" ]] && break
			done
			[[ $__i__ -ge 0 ]] || return 1

			eval __v1__='${'$1'[$__k__]}' __v2__='${'$2'[$__k__]}'

			[[ "$__v1__" == "$__v2__" ]] || return 1
		done
	else
		[[ "${!1}" == "${!2}" ]] || return 1
	fi

	return 0
}

function _t {
	local tp=t
	[[ $1 == *[![:digit:]]* ]] && tp=test_

	declare -F $tp$1 >/dev/null && return 0
	declare -F _$tp$1 >/dev/null && return 3
	return 1
}

function t {
	local t fct tests=(); local -A test=()

	while read -r -a fct; do
		fct=${fct[-1]}

		[[ $fct == test_* ]] || continue

		t=${fct#test_}

		test[$t]=$fct
		[[ $# -eq 0 ]] && tests+=($t)
	done < <(
		declare -F
	)

	if [[ $# -gt 0 ]]; then
		for t; do
			[[ ${test[$t]} ]] || _t "$t" || t_error "Invalid test id: $t"

			if [[ $t == *[!0-9]* ]]; then
				fct=test_$t
			else
				fct=t$t
			fi

			test[$t]=$fct
			tests+=($t)
		done
	fi

	for t in "${tests[@]}"; do
		fct=${test[$t]}

		( $fct &>/dev/null ) || : # warmup
	done

	for t in "${tests[@]}"; do
		fct=${test[$t]}

		[[ $T_VERBOSE ]] && t_log Running: $t >&2

		err= line=

		if [[ $T_COUNT -gt 1 ]]; then
			time (
				for ((i=0; i<T_COUNT; i++)); do
					$fct
				done &>/dev/null
			) || err=_
		else
			( $fct ) || err=_
		fi

		if [[ $err ]]; then
			t_log '[FAIL]' $t

			exit 1
		elif [[ $t != __t_* ]]; then
			t_log '[PASS]' $t
		fi
	done
}

T_COUNT=
T_VERBOSE=

while [[ $# -gt 0 ]]; do
case $1 in
-c*)
	T_COUNT=${1#*c}
	if [[ $T_COUNT ]]; then
		shift
	else
		T_COUNT=$2
		shift 2 || t_usage
	fi
	;;
-v)
	T_VERBOSE=_
	shift
	;;
-h)
	t_usage
	;;
--)
	shift
	break
	;;
-*)
	t_error "Unknown option: $1"
	;;
*)
	break
	;;
esac
done

test___t_cmp() {
	local val1 val2
	local -a arr1=() arr2=()
	local -A ass1=() ass2=()

	t_cmp val1 val2 || t_fail
	t_cmp arr1 arr2 || t_fail
	t_cmp ass1 ass2 || t_fail

	! t_cmp val1 arr2 || t_fail
	! t_cmp arr1 ass2 || t_fail
	! t_cmp ass1 val2 || t_fail

	local val3
	local -a arr3
	local -A ass3

	[[ ${ass1@a} == ${ass2@a} && ${ass3@a} == ${ass1@a} ]] || t_fail

	val3=ass3

	[[ ${!val3@a} != ${ass1@a} ]] || t_fail ## ??? attributes of an uninitialized variable (ass3) is always empty when using name reference

	ass3=()

	[[ ${!val3@a} == ${ass1@a} ]] || t_fail

	var1='Pow Pow'
	var2=Pow\ Pow

	t_cmp var1 var2 || t_fail

	var2=${var1,}

	! t_cmp var1 var2 || t_fail

	arr1=("$var1")

	[[ $var1 == "$arr1" ]] || t_fail
	! t_cmp var1 arr1 || t_fail

	arr2=("$var1")

	t_cmp arr1 arr2 || t_fail

	arr2+=('')

	! t_cmp arr1 arr2 || t_fail

	arr1+=('')

	t_cmp arr1 arr2 || t_fail

	arr1+=(Abc) arr2+=(Abc)

	t_cmp arr1 arr2 || t_fail

	arr1=([0]=cat [1]=dog [2]=horse)
	ass1=([0]=cat [1]=dog [2]=horse)

	local i
	for ((i=0; i<${#arr1[@]}; i++)); do
		[[ "${arr1[$i]}" == "${ass1[$i]}" ]] || t_fail
	done

	! t_cmp arr1 ass1 || t_fail

	ass1=([cat]=purr [dog]=bark [horse]=neigh)

	! t_cmp ass1 ass2 || t_fail

	local k
	for k in "${!ass1[@]}"; do
		ass2[$k]=${ass1[$k]}
	done

	t_cmp ass1 ass2 || t_fail
}

for tf in *.test; do
	. $tf
done

t "$@"
