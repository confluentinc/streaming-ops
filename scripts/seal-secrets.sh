#!/bin/bash
#
# Script to seal secrets
#

# Make sure an environment has been passed into the script.
if [[ "$1" == "" ]]; then
    echo "Please provide an environment you want to seal (e.g. bh)"
    exit
fi

if ! which kubeseal > /dev/null 2>&1; then
  echo 'Please install kubeseal. On MacOS you can use "make kubeseal".'
  exit
fi

if ! which yq > /dev/null 2>&1; then
  echo 'Please install yq. On MacOS you can use "make yq".'
  exit
fi

# Make sure you have the latest version of kubeseal installed.
KUBESEAL_VERSION_CHECK=$(kubeseal --version | grep -c "0.12")
if [ "$KUBESEAL_VERSION_CHECK" -ne 1 ]; then
  echo 'Please install kubeseal v0.12.x'
  exit 1
fi

# Set a variable to specify the environment we are working on.
environments=$1

function validation {
    validate_secret_name "$1" && validate_image_pull_secret "$1"
}

function validate_secret_name {
    FILE=$1

    NAME=$(yq r "$FILE" metadata.name)
    NAMESPACE=$(yq r "$FILE" metadata.namespace)

    if [[ ! $(basename "$FILE") == "${NAMESPACE}-${NAME}.yaml" ]]; then
        printf "WARN - Skipping secret %s; file name does not match <namespace>-<secret name>.yaml\n" "${secret}"
        return 1
    else
        return 0
    fi
}

function validate_image_pull_secret {
    FILE=$1

    if [[ $(basename "$FILE") == *"image-pull-secret.yaml" ]]; then
        TYPE=$(yq r "$FILE" type)
        if [[ "${TYPE}" != "kubernetes.io/dockerconfigjson" ]]; then
            printf "WARN - Skipping secret %s; image pull secrets must be of type kubernetes.io/dockerconfigjson\n" "${secret}"
            return 1
        fi
    fi
    return 0
}

function validate_dirs_exists {
    for dir in ${public_key} ${sealed_secret_dir} ${to_seal_dir} ${sealed_dir} ; do
        if [[ ! -e $dir ]]; then
          printf "ERROR - %s not found.\n" "${dir}"
          return 1
        fi
    done
}

function get_environments {
    for dir in local-toseal/* ; do
        echo -n "${dir##*/} "
    done
}

function validate_secrets_in_dir {
    if ! (ls "${to_seal_dir}"/*.yaml 1> /dev/null 2>&1); then
        return 1
    fi
}

function seal_secrets {
    for secret in "$to_seal_dir"/*.yaml; do
        if validation "${secret}"; then

          # Obtain just the filename without the file type.
          filename=${secret##*/}
          filename_without_file_type=${filename%.*}

          # Use kubeseal to construct a Sealed Secret with the same name.
          kubeseal --format=yaml --cert="${public_key}" < "$secret" > "${sealed_secret_dir}/${filename_without_file_type}.yaml"

          # Move secret which has been sealed to the "sealed" directory to stop constant re-sealing.
          mv "${secret}" "${sealed_dir}"

          printf "INFO - Successfully sealed %s\n" "${secret}"
        fi
    done
}

if [[ ${environments} == "all" ]]; then
    environments=$(get_environments)
    echo "Environments contains: ${environments}"
fi

for environment in ${environments}; do
    public_key=secrets/keys/${environment}.crt
    sealed_secret_dir="secrets/sealed/${environment}"
    to_seal_dir="secrets/local-toseal/${environment}"
    sealed_dir="secrets/local-sealed/${environment}"

    validate_dirs_exists
    if [[ $? -ne 0 ]]; then
        break
    fi

    validate_secrets_in_dir
    if [[ $? -ne 0 ]]; then
        echo "No files to seal for ${to_seal_dir}"
        continue
    fi  

    seal_secrets
done

