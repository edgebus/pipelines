#!/bin/sh
#
#
# EdgeBus's Pipelines Toolchain
#
# Implemented as a POSIX-compliant function to target on sh, dash, bash, ksh, zsh
# Implemented by Max Anurin <theanurin@gmail.com>
#

# auto|bitbucket|droneci|github|gitlab|woodpecker

{ # this ensures the entire script is downloaded #

set -eu

# = Debug =
if [ "${CI-false}" = "false" ]; then
    BITBUCKET_GIT_HTTP_ORIGIN=http://bitbucket.org/theanurin/wifox
    BITBUCKET_BUILD_NUMBER=42
    BITBUCKET_COMMIT=e23bda2db0bab9ce4443ee333318df218c7a7ebd
    BITBUCKET_BRANCH=master
    # BITBUCKET_TAG="1.0.0-rc25"
    # BITBUCKET_TAG="1.0.0"
fi
# =========


parse_release_candidate_number() {
    if echo "${1}" | egrep -qe '-rc[0-9]+$'; then
        echo "${1}" | sed 's/^.*-rc//'
    else
        echo ""
    fi
}

parse_version() {
    if echo "${1}" | egrep -qe '-rc[0-9]+$'; then
        echo "${1}" | rev | cut -d- -f2 | rev
    else
        echo "${1}" | rev | cut -d- -f1 | rev
    fi    
}


log_trace() {
    if [ "${SSC_PIPELINE__TRACE}" = "1" -o "${SSC_PIPELINE__DEBUG}" = "1" ]; then
        command echo "${1}" >&2
    fi
}

log_debug() {
    if [ "${SSC_PIPELINE__DEBUG}" = "1" ]; then
        command echo "${1}" >&2
    fi
}

log_info() {
    command echo "${1}" >&2
}

log_warn() {
    command echo "${1}" >&2
}

log_fatal_exit() {
    command echo "${1}" >&2
    command exit "${2}"
}

source_platform__bitbucket() {
    local LAST_COMMIT_UNIX_TIMESTAMP
    LAST_COMMIT_UNIX_TIMESTAMP=$(git --no-pager log -1 --format=%at)
    if [ "$(uname)" = "Darwin" ]; then
        #  Mac OS X platform
        export SSC_PIPELINE__COMMIT_CREATED_AT_ISO8601=$(date -r "${LAST_COMMIT_UNIX_TIMESTAMP}" +'%Y-%m-%dT%H:%M:%SZ')
        export SSC_PIPELINE__PIPELINE_CREATED_AT_ISO8601=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    else
        export SSC_PIPELINE__COMMIT_CREATED_AT_ISO8601=$(date --utc --date="@${LAST_COMMIT_UNIX_TIMESTAMP}" +'%Y-%m-%dT%H:%M:%SZ')
        export SSC_PIPELINE__PIPELINE_CREATED_AT_ISO8601=$(date --utc +'%Y-%m-%dT%H:%M:%SZ')
    fi
    export SSC_PIPELINE__ID="${BITBUCKET_BUILD_NUMBER}"
    export SSC_PIPELINE__CI_URL="${BITBUCKET_GIT_HTTP_ORIGIN}/pipelines/results/${BITBUCKET_BUILD_NUMBER}"
    export SSC_PIPELINE__PROJECT_URL="${BITBUCKET_GIT_HTTP_ORIGIN}"
    export SSC_PIPELINE__COMMIT_REF="${BITBUCKET_COMMIT}"
    export SSC_PIPELINE__COMMIT_REF_SHORT=$(echo "${SSC_PIPELINE__COMMIT_REF}" | head -c 8)

    if [ ! -z "${BITBUCKET_TAG+x}" ]; then
        if [ ! -z "${BITBUCKET_BRANCH+x}" ]; then
            log_fatal_exit "Variables BITBUCKET_TAG and BITBUCKET_BRANCH are set same time. Cannot continue." 127
        fi
        export SSC_PIPELINE__BRANCH=""
        export SSC_PIPELINE__RC_NUMBER=$(parse_release_candidate_number "${BITBUCKET_TAG}")
        export SSC_PIPELINE__VERSION=$(parse_version "${BITBUCKET_TAG}")

        if [ -n "${SSC_PIPELINE__RC_NUMBER}" ]; then
            export SSC_PIPELINE__IS_RELEASE_CANDIDATE="yes"
            # export SSC_PIPELINE__VERSION_SLUG="rc${SSC_PIPELINE__RC_NUMBER}"
            # export SSC_PIPELINE__VERSION_SLUG_SHORT="rc${SSC_PIPELINE__RC_NUMBER}"
            # export SSC_PIPELINE__IMAGE_TAG_VERSION="${SSC_PIPELINE__VERSION}-rc${SSC_PIPELINE__RC_NUMBER}"
        else
            export SSC_PIPELINE__IS_RELEASE_CANDIDATE="no"
            # export SSC_PIPELINE__VERSION_SLUG=""
            # export SSC_PIPELINE__VERSION_SLUG_SHORT=""
            export SSC_PIPELINE__VERSION_MAJOR="$(echo "${SSC_PIPELINE__VERSION}" | cut -d. -f1)"
            export SSC_PIPELINE__VERSION_MAJOR_MINOR="$(echo "${SSC_PIPELINE__VERSION}" | cut -d. -f1-2)"
            # export SSC_PIPELINE__IMAGE_TAG_VERSION="${SSC_PIPELINE__VERSION}"
        fi
    else
        export SSC_PIPELINE__BRANCH="${BITBUCKET_BRANCH}"
        export SSC_PIPELINE__RC_NUMBER=""
        export SSC_PIPELINE__VERSION=""
        export SSC_PIPELINE__VERSION_MAJOR=""
        export SSC_PIPELINE__VERSION_MAJOR_MINOR=""
        # export SSC_PIPELINE__VERSION_SLUG="${BITBUCKET_BRANCH}.${SSC_PIPELINE__COMMIT_REF}"
        # export SSC_PIPELINE__VERSION_SLUG_SHORT="${BITBUCKET_BRANCH}.${SSC_PIPELINE__COMMIT_REF_SHORT}"
        # export SSC_PIPELINE__IMAGE_TAG_VERSION="${BITBUCKET_BRANCH}"
    fi
}

help_exit0__docker_image__build() {
    command cat <<EOF
        curl https://raw.githubusercontent.com/edgebus/pipelines/0.0.0/
        cat ssc-pipelines.sh | sh -s -- \
          --ci-platform=auto \
          docker-image build \
            --docker-file=./docker/image/facade/Dockerfile \
            --docker-context=. \
            --docker-tag=... \
            --docker-platform=linux/amd64 \
            --docker-builder=BuildKit \
            --build-configuration=snapshot \
            --build-commit-reference=... \
            --build-commit-timestamp=... \
            --build-pipeline-url=... \
            --build-project-url=... \
            --build-release-candidate-number=... \
            --build-version=... \
            --build-version-appender=... \
            .
EOF
    exit 0
}

unexpected_arg_err() {
    log_fatal_exit "Unexpected argument: $@" 1
}

main__docker_image__build() {
    while [ "$#" -ne 0 ]; do
        case "${1}" in
            --docker-builder=*)
                DOCKER_BUILDER="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-context=*)
                DOCKER_CONTEXT="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-file=*)
                DOCKER_FILE="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-platform=*)
                DOCKER_PLATFORM="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-fully-qualified-image-name=*)
                SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --configuration=*)
                CONFIGURATION="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --commit-reference=*)
                COMMIT_REF="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --commit-date-iso8601=*)
                COMMIT_DATE_ISO8601="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --pipeline-url=*)
                PIPELINE_URL="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --project-url=*)
                PROJECT_URL="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --release-candidate-number=*)
                RC_NUMBER="$(command echo "$1" | command cut -d= -f2)"
                ;;
            *)
                unexpected_arg_err "${1}"
                ;;
        esac
        shift
    done

    if [ -z "${DOCKER_BUILDER+x}" ]; then
        DOCKER_BUILDER="BuildKit"
        log_debug "[Docker Build] Using default docker builder '${DOCKER_BUILDER}'"
    fi

    if [ -z "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME+x}" ]; then
        local PROJECT_PATH
        local IMAGE_NAME
        PROJECT_PATH=$(node -e "console.log(new URL('${SSC_PIPELINE__PROJECT_URL}').pathname);")
        IMAGE_NAME=$(basename $(dirname "${DOCKER_FILE}"))
        SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME="${SSC_PIPELINE__DOCKER__REGISTRY__AUTHORITY}${PROJECT_PATH}/${IMAGE_NAME}"
        log_debug "[Docker Build] Resolve fully qualified image name: ${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}"
    fi

    if [ -z "${COMMIT_REF+x}" ]; then
        COMMIT_REF="${SSC_PIPELINE__COMMIT_REF}"
        log_debug "[Docker Build] Resolve commit reference: ${COMMIT_REF}"
    fi

    if [ -z "${COMMIT_DATE_ISO8601+x}" ]; then
        COMMIT_DATE_ISO8601="${SSC_PIPELINE__COMMIT_CREATED_AT_ISO8601}"
        log_debug "[Docker Build] Resolve commit date: ${COMMIT_DATE_ISO8601}"
    fi

    if [ -z "${PIPELINE_DATE_ISO8601+x}" ]; then
        PIPELINE_DATE_ISO8601="${SSC_PIPELINE__PIPELINE_CREATED_AT_ISO8601}"
        log_debug "[Docker Build] Resolve pipeline date: ${PIPELINE_DATE_ISO8601}"
    fi

    if [ -z "${PIPELINE_URL+x}" ]; then
        PIPELINE_URL="${SSC_PIPELINE__CI_URL}"
        log_debug "[Docker Build] Resolve pipeline URL: ${PIPELINE_URL}"
    fi

    if [ -z "${PROJECT_URL+x}" ]; then
        PROJECT_URL="${SSC_PIPELINE__PROJECT_URL}"
        log_debug "[Docker Build] Resolve project URL: ${PROJECT_URL}"
    fi

    if [ -z "${RC_NUMBER+x}" ]; then
        RC_NUMBER="${SSC_PIPELINE__RC_NUMBER}"
        log_debug "[Docker Build] Resolve release candidate number: ${RC_NUMBER}"
    fi

    # local VERSION_SLUG
    # if [ "${CONFIGURATION}" != "release" ]; then
    #     VERSION_SLUG="${SSC_PIPELINE__VERSION_SLUG}-${CONFIGURATION}"
    # else
    #     VERSION_SLUG="${SSC_PIPELINE__VERSION_SLUG}"
    # fi
    # log_debug "[Docker Build] Resolve version slug: ${VERSION_SLUG}"

    # local VERSION_SLUG_SHORT
    # if [ "${CONFIGURATION}" != "release" ]; then
    #     VERSION_SLUG_SHORT="${SSC_PIPELINE__VERSION_SLUG_SHORT}-${CONFIGURATION}"
    # else
    #     VERSION_SLUG_SHORT="${SSC_PIPELINE__VERSION_SLUG_SHORT}"
    # fi
    # log_debug "[Docker Build] Resolve version slug (short): ${VERSION_SLUG_SHORT}"

    if [ "${DOCKER_BUILDER}" = "Buildx" ]; then
        log_fatal_exit "[Docker Build] Buildx not supported yet." 42
    else
        if [ "${DOCKER_BUILDER}" = "BuildKit" ]; then
            export DOCKER_BUILDKIT=1
        fi

        set -- \
            --platform "${DOCKER_PLATFORM}" \
            --build-arg CONFIGURATION="${CONFIGURATION}" \
            --build-arg COMMIT_REF="${COMMIT_REF}" \
            --build-arg COMMIT_DATE_ISO8601="${COMMIT_DATE_ISO8601}" \
            --build-arg PIPELINE_URL="${PIPELINE_URL}" \
            --build-arg PROJECT_URL="${PROJECT_URL}" \
            --build-arg RC_NUMBER="${RC_NUMBER}" \
            --build-arg VERSION="${SSC_PIPELINE__VERSION}" \
            --build-arg BRANCH="${SSC_PIPELINE__BRANCH}" \
            --file "${DOCKER_FILE}"

        local IMAGE_TAG_SUFFIX
        if [ "${CONFIGURATION}" != "release" ]; then
            IMAGE_TAG_SUFFIX="-${CONFIGURATION}"
        else
            IMAGE_TAG_SUFFIX=""
        fi

        if [ -n "${SSC_PIPELINE__VERSION}" ]; then
            if [ "${SSC_PIPELINE__IS_RELEASE_CANDIDATE}" != "yes" ]; then
                set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__VERSION_MAJOR_MINOR}${IMAGE_TAG_SUFFIX}"
                set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__VERSION_MAJOR}${IMAGE_TAG_SUFFIX}"
                if [ "${CONFIGURATION}" = "release" ]; then
                    set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:latest"
                fi
            fi
            set -- "$@" --tag  "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF}${IMAGE_TAG_SUFFIX}"
            set -- "$@" --tag  "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF_SHORT}${IMAGE_TAG_SUFFIX}"
            set -- "$@" --tag  "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__VERSION}"
        else
            set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__BRANCH}.${SSC_PIPELINE__COMMIT_REF}${IMAGE_TAG_SUFFIX}"
            set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__BRANCH}.${SSC_PIPELINE__COMMIT_REF_SHORT}${IMAGE_TAG_SUFFIX}"
            set -- "$@" --tag "${SSC_PIPELINE__DOCKER__FILL_QUALIFIED_IMAGE_NAME}:${SSC_PIPELINE__BRANCH}"
        fi

        command echo docker build \
            "$@" \
            "${DOCKER_CONTEXT}"
    fi

    echo "FINISH"
    exit 1


}

main__docker_image__publish() {
    while [ "$#" -ne 0 ]; do
        case "${1}" in
            --docker-registry-ca-file=*)
                DOCKER_IMAGE__PUSH__REGISTRY_CA_FILE="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-registry-auth-token=*)
                DOCKER_IMAGE__PUSH__REGISTRY_AUTH_TOKEN="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-registry-auth-user=*)
                DOCKER_IMAGE__PUSH__REGISTRY_AUTH_USER="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-registry-path=*)
                DOCKER_IMAGE__PUSH__REGISTRY_PATH="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-source-image-name=*)
                DOCKER_IMAGE__PUSH__SOURCE_IMAGE_NAME="$(command echo "$1" | command cut -d= -f2)"
                ;;
            --docker-target-image-name=*)
                DOCKER_IMAGE__PUSH__TARGET_IMAGE_NAME="$(command echo "$1" | command cut -d= -f2)"
                ;;
        esac
        shift
    done

    if [ ! -z "${DOCKER_IMAGE__PUSH__REGISTRY_CA_FILE+x}" ]; then
        mkdir -p "/etc/docker/certs.d/${DOCKER_IMAGE__PUSH__REGISTRY_AUTHORITY}"
        cat "${DOCKER_IMAGE__PUSH__REGISTRY_CA_FILE}" > "/etc/docker/certs.d/${DOCKER_IMAGE__PUSH__REGISTRY_AUTHORITY}/ca.crt"
    fi

    echo "${DOCKER_IMAGE__PUSH__REGISTRY_AUTH_TOKEN}" | docker login --username "${DOCKER_IMAGE__PUSH__REGISTRY_AUTH_USER}" --password-stdin "${DOCKER_IMAGE__PUSH__REGISTRY_AUTHORITY}"
    
    local DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME
    DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME="${DOCKER_IMAGE__PUSH__REGISTRY_AUTHORITY}/${DOCKER_IMAGE__PUSH__REGISTRY_PATH}/${DOCKER_IMAGE__PUSH__IMAGE__NAME}"

    if [ -n "${SSC_PIPELINE__VERSION}" ]; then
        if [ "${SSC_PIPELINE__IS_RELEASE_CANDIDATE}" != "yes" ]; then
            command docker tag  "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION_MAJOR_MINOR}"
            command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION_MAJOR_MINOR}"
            command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION_MAJOR}"
            command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:latest"
        fi
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF}"
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF_SHORT}"
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}"
    else
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF}"
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}.${SSC_PIPELINE__COMMIT_REF_SHORT}"
        command docker push "${DOCKER_IMAGE__PUSH__FULL_IMAGE_NAME}:${SSC_PIPELINE__VERSION}"
    fi
}

main__docker_image() {
    while [ "$#" -ne 0 ]; do
        case "${1}" in
            build)
                shift
                main__docker_image__build "$@"
                break
                ;;
            publish)
                shift
                main__docker_image__publish "$@"
                break
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    unexpected_arg_err "${1}"
}

main() {
    local SSC_PIPELINE__CI_PLATFORM

    SSC_PIPELINE__CI_PLATFORM="auto"

    while [ "$#" -ne 0 ]; do
        case "${1}" in
            --ci-platform=*)
                SSC_PIPELINE__CI_PLATFORM="$(echo "${1}" | cut -d= -f2)"
                ;;
            --trace)
                SSC_PIPELINE__TRACE=1
                ;;
            --debug)
                SSC_PIPELINE__DEBUG=1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [ -z "${SSC_PIPELINE__TRACE+x}" ]; then
        SSC_PIPELINE__TRACE=0
    fi

    if [ -z "${SSC_PIPELINE__DEBUG+x}" ]; then
        SSC_PIPELINE__DEBUG=0
    fi

    if [ "$#" -eq 0 ]; then
        log_fatal_exit "Command was not provided" 1
    fi

    if [ "${SSC_PIPELINE__TRACE}" = "1" ]; then
        set -x
    fi

    case "${SSC_PIPELINE__CI_PLATFORM}" in
        auto)
            log_fatal_exit "CI platform '${SSC_PIPELINE__CI_PLATFORM}' is not supported yet." 1
            ;;
        bitbucket)
            source_platform__bitbucket
            ;;
        *)
            log_fatal_exit "Unsupported CI platform '${SSC_PIPELINE__CI_PLATFORM}'" 1
            ;;
    esac

    local COMMAND
    COMMAND="${1}"
    shift

    case "${COMMAND}" in
        docker-image)
            main__docker_image "$@"
            ;;
        *)
            log_fatal_exit "Unsupported command '${COMMAND}'" 1
            ;;
    esac
    shift
}

main "$@"

} # this ensures the entire script is downloaded #