#!/bin/bash
set -e
shopt -s extglob

#FOR THE CLEANEST TEST
# DISABLE_COMPILATION_CACHES=True

#REQUIRES
# 1 param of build_if_gcc54

# COMMON OPTIONAL PARAMS
# OPEN_DOCKER_BASH_INSTEAD=True
# VALGRIND=True
# SIM_COVERAGE=True
# TEST_C
# BUILD_RELEASE
# TEST_RUST
# CLEAN_RUST_TARGETS
# UPLOAD_BUILD, UPLOAD_DOCS
# DISABLE_COMPILATION_CACHES=True

#OPTIONAL
# SIM_TRAVIS_TAG=v0.0.99999
# DOCKER_IMAGE override
# PACKAGE_SUFFIX like x86_64-linux-gcc48-eglibc219
# FETCH_COMMIT_SUFFIX like mac64
# TEST_C_DEBUG_BUILD
export BUILD_QUIETER="$BUILD_QUIETER"

echo_maybe(){
	if [[ "$BUILD_QUIETER" -ne "True" ]]; then
	    echo "$1"
	fi
}

if [[ "$BUILD_QUIETER" != "True" ]]; then
	exec 9>&1
else
	exec 9>/dev/null
fi



echo_maybe "Preparing to build Imageflow"

# We change this default (not like Travis), but for speed. 
# Not relevant when DISABLE_COMPILATION_CACHES=True 
export CLEAN_RUST_TARGETS="${CLEAN_RUST_TARGETS:-False}"

export IMAGEFLOW_BUILD_OVERRIDE="${IMAGEFLOW_BUILD_OVERRIDE}"




# First parameter to script must be the name of the docker image (excluding imazen/)
export IMAGE_NAME="$1"

export TARGET_CPU="${TARGET_CPU:-x86_64}"


# Set DOCKER_IMAGE to override entire name
export DOCKER_IMAGE="${DOCKER_IMAGE:-imazen/$IMAGE_NAME}"

############## Paths for caching
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$1"
export TEST_SH_CACHE_DIR="${HOME}/.docker_imageflow_caches"
#export TEST_SH_CACHE_DIR="${SCRIPT_DIR}/../.docker_imageflow_caches"

export WORKING_DIR="${TEST_SH_CACHE_DIR}/.docker_${IMAGE_NAME}"
export SHARED_CACHE="${TEST_SH_CACHE_DIR}/.shared_cache"

echo_maybe "===================================================================== [test.sh]"
echo_maybe "Rsync imageflow/* into dedicated work folder ${WORKING_DIR}"
echo_maybe

[[ -d "$WORKING_DIR" ]] || mkdir -p "$WORKING_DIR"
rsync -q -av --delete "${SCRIPT_DIR}/../../.." "$WORKING_DIR" --filter=':- .gitignore'  --exclude="target/" #--exclude-from "${SCRIPT_DIR}/../exclude_paths.txt" 
(
	cd "$WORKING_DIR"

	############## Set up travis env


	## REQUIRED ALWAYS
	export TRAVIS_BUILD_DIR="${WORKING_DIR}"
	export DOCKER_IMAGE="${DOCKER_IMAGE}"
	export CI="true"

	## REQUIRED FOR SIMULATION
	export SIM_CI="True"
	export SIM_OPEN_BASH="${OPEN_DOCKER_BASH_INSTEAD:-False}"
	export SIM_DOCKER_CACHE_VAR


	
	mkdir -p "${WORKING_DIR}_cache/target/debug" || true
	mkdir -p "${WORKING_DIR}_cache/target/release" || true
	mkdir -p "${WORKING_DIR}_cache/conan_data" || true
	mkdir -p "${WORKING_DIR}_cache/ccache" || true
	mkdir -p "${WORKING_DIR}_cache/c_components/build" || true


	# The first two are only needed in test.sh, since we're rsycning away the whole /target folder
	export SIM_DOCKER_CACHE_VARS=(
		-v 
		"${WORKING_DIR}_cache/target/debug:/home/conan/imageflow/target/debug"
		-v 
		"${WORKING_DIR}_cache/target/release:/home/conan/imageflow/target/release"
		-v 
		"${WORKING_DIR}_cache/conan_data:/home/conan/.conan/data" 
		-v 
		"${HOME}/.cargo:/home/conan/host_cargo" 
		-v 
		"${WORKING_DIR}_cache/ccache:/home/conan/.ccache"
		-v 
		"${WORKING_DIR}_cache/c_components/build:/home/conan/imageflow/c_components/build"  
	)
	# The very last is unique to test.sh (for speed?)
	#Ensure that .cargo is NOT volume mapped; cargo will not work. Also, cargo fetches faster than rsync, it seems?


	if [[ "$DISABLE_COMPILATION_CACHES" == 'True' ]]; then		
		echo "DISABLE_COMPILATION_CACHES=${DISABLE_COMPILATION_CACHES:-False}"
		export SIM_DOCKER_CACHE_VARS=()
	fi


	## For artifacts to be created
	export TRAVIS_PULL_REQUEST=false
	export TRAVIS_PULL_REQUEST_SHA=
	export UPLOAD_BUILD="${UPLOAD_BUILD:-True}"
	export PACKAGE_SUFFIX

	if [[ "${TARGET_CPU}" == "x86_64" || "${TARGET_CPU}" == "" ]]; then
		ARCH_SUFFIX="x86_64"
	else  
		if [[ "${TARGET_CPU}" == "native" ]]; then
			ARCH_SUFFIX="HOST-NATIVE"
		fi 
	fi 

	if [[ "$DOCKER_IMAGE" == 'imazen/build_if_gcc48' ]]; then
		export PACKAGE_SUFFIX="${PACKAGE_SUFFIX:-${ARCH_SUFFIX}-linux-gcc48-eglibc219}"
	fi
	if [[ "$DOCKER_IMAGE" == 'imazen/build_if_gcc54' ]]; then
		export PACKAGE_SUFFIX="${PACKAGE_SUFFIX:-${ARCH_SUFFIX}-linux-gcc54-glibc223}"
	fi
	if [[ "$DOCKER_IMAGE" == 'imazen/musl' ]]; then
		export PACKAGE_SUFFIX="${PACKAGE_SUFFIX:-${ARCH_SUFFIX}-linux-musl}"
	fi

	export TRAVIS_BUILD_NUMBER=99999
	export TRAVIS_JOB_NUMBER=88888
	export TRAVIS_BRANCH=

	## For docs
	export UPLOAD_DOCS="${UPLOAD_DOCS:-True}"

	## For tagged releases
	export TRAVIS_TAG="$SIM_TRAVIS_TAG"
	## For artifact-by-commit
	export FETCH_COMMIT_SUFFIX="${FETCH_COMMIT_SUFFIX}"

	## CONFIGURATION
	# VALGRIND=True or False
	# 
	## MOST LIKELY TO GET POLLUTED
	# GIT_* vars
	# BUILD_RELEASE
	# TEST_C
	# TEST_C_DEBUG_BUILD
	# TEST_RUST
	# CLEAN_RUST_TARGETS
	# IMAGEFLOW_SERVER

	#In some configurations, true
	export COVERAGE=${SIM_COVERAGE:-False}
	export COVERALLS=
	export COVERALLS_TOKEN=


	conan user 1>&9
	# For os x convenience
	if [[ "$(uname -s)" == 'Darwin' ]]; then
		eval "$(docker-machine env default)"
	fi

	TRAVIS_RUN_VARS=(
		"PACKAGE_SUFFIX=${PACKAGE_SUFFIX}"
		"DOCKER_IMAGE=${DOCKER_IMAGE}"
		"TARGET_CPU=${TARGET_CPU}"
		"VALGRIND=${VALGRIND}"
		"UPLOAD_BUILD=${UPLOAD_BUILD}"
		"UPLOAD_DOCS=${UPLOAD_DOCS}"
		"TRAVIS_BUILD_DIR=${TRAVIS_BUILD_DIR}"
		"CI=${CI}"
		"SIM_CI=${SIM_CI}"
		"SIM_OPEN_BASH=${SIM_OPEN_BASH}"
		"SIM_DOCKER_CACHE_VARS="
		"${SIM_DOCKER_CACHE_VARS[@]}"
		"BUILD_DEBUG=${BUILD_DEBUG}"
		"BUILD_QUIETER=${BUILD_QUIETER}"
		"IMAGEFLOW_BUILD_OVERRIDE=${IMAGEFLOW_BUILD_OVERRIDE}"
		"BUILD_RELEASE=${BUILD_RELEASE}"
		"CLEAN_RUST_TARGETS=${CLEAN_RUST_TARGETS}"
		"TRAVIS_BUILD_NUMBER=${TRAVIS_BUILD_NUMBER}"
		"TRAVIS_JOB_NUMBER=${TRAVIS_JOB_NUMBER}"
		"TRAVIS_BRANCH=${TRAVIS_BRANCH}"
		"TRAVIS_TAG=${TRAVIS_TAG}"
		"FETCH_COMMIT_SUFFIX=${FETCH_COMMIT_SUFFIX}"
		"TEST_C_DEBUG_BUILD=${TEST_C_DEBUG_BUILD}"
		"TEST_RUST=${TEST_RUST}"
		"TEST_C=${TEST_C}"
		"IMAGEFLOW_SERVER=${IMAGEFLOW_SERVER}"
		"COVERAGE=${COVERAGE}"
		"COVERALLS=${COVERALLS}"
		"COVERALLS_TOKEN=${COVERALLS_TOKEN}"
	)

	if [[ "$BUILD_QUIETER" -ne "True" ]]; then
		printf "TRAVIS_RUN_VARS: \n%s\n" "${TRAVIS_RUN_VARS[@]}"
	fi 
	
	#echo "SIM_DOCKER_CACHE_VARS ${SIM_DOCKER_CACHE_VARS[*]}"

	echo_maybe ""
	echo_maybe "switching to ./ci/travis_run.sh ================================"

	#echo "SIM_DOCKER_CACHE_VARS ${SIM_DOCKER_CACHE_VARS[*]}"
	
	SIM_DOCKER_CACHE_VARS="${SIM_DOCKER_CACHE_VARS[*]}" ./ci/travis_run.sh
)