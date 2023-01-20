export AUTO_SWITCH_MAMBAENV_VERSION='0.0.1'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! type mamba > /dev/null; then
    export DISABLE_AUTO_SWITCH_MAMBAENV="1"
    printf "\e[1m\e[31m"
    printf "zsh-auto-switch-mambaenv requires mamba to be installed!\n\n"
    printf "\e[0m\e[39m"
    printf "If this is already installed but you are still seeing this message, \nadd the "
    printf "following to your ~/.zshenv:\n\n"
    printf "\e[1m"
    printf ". YOUR_MAMBA_PATH/etc/profile.d/mamba.sh\n"
    printf "\n"
    printf "\e[0m"
    printf "\e[0m"
    printf "\n"
fi

function _maybeactivate() {
  if [[ -z "$CONDA_DEFAULT_ENV" || "$1" != "$(basename $CONDA_DEFAULT_ENV)" ]]; then
     if [ -z "$AUTOSWITCH_SILENT" ]; then
        printf "Switching mamba environment: %s  " $1
     fi

     mamba activate "$1"

     if [ -z "$AUTOSWITCH_SILENT" ]; then
       # For some reason python --version writes to st derr
       printf "[%s]\n" "$(python --version 2>&1)"
     fi
  fi
}

# Gives the path to the nearest parent .menv file or nothing if it gets to root
function _check_menv_path()
{
    local check_dir=$1

    if [[ -f "${check_dir}/.menv" ]]; then
        printf "${check_dir}/.menv"
        return
    else
        if [ "$check_dir" = "/" ]; then
            return
        fi
        _check_menv_path "$(dirname "$check_dir")"
    fi
}

# Automatically switch mamba environment when .menv file detected
function check_menv()
{
    if [ "AS_MENV:$PWD" != "$MYOLDPWD" ]; then
        # Prefix PWD with "AS_MENV:" to signify this belongs to this plugin
        # this prevents the AUTONAMEDIRS in prezto from doing strange things
        # (Since zsh-autoswitch-virtualenv use "AS:" prefix, we instead use "AS_MENV:"
        # See https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv/issues/19
        MYOLDPWD="AS_MENV:$PWD"

        SWITCH_TO=""

        # Get the .menv file, scanning parent directories
        menv_path=$(_check_menv_path "$PWD")
        if [[ -n "$menv_path" ]]; then

          stat --version &> /dev/null
          if [[ $? -eq 0 ]]; then   # Linux, or GNU stat
            file_owner="$(stat -c %u "$menv_path")"
            file_permissions="$(stat -c %a "$menv_path")"
          else                      # macOS, or FreeBSD stat
            file_owner="$(stat -f %u "$menv_path")"
            file_permissions="$(stat -f %OLp "$menv_path")"
          fi

          if [[ "$file_owner" != "$(id -u)" ]]; then
            printf "AUTOSWITCH WARNING: Mamba environment will not be activated\n\n"
            printf "Reason: Found a .menv file but it is not owned by the current user\n"
            printf "Change ownership of $menv_path to '$USER' to fix this\n"
          elif [[ "$file_permissions" != "600" ]]; then
            printf "AUTOSWITCH WARNING: Mamba environment will not be activated\n\n"
            printf "Reason: Found a .menv file with weak permission settings ($file_permissions).\n"
            printf "Run the following command to fix this: \"chmod 600 $menv_path\"\n"
          else
            SWITCH_TO="$(<"$menv_path")"
          fi
        fi

        if [[ -n "$SWITCH_TO" ]]; then
          _maybeactivate "$SWITCH_TO"
        else
          _default_menv
        fi
    fi
}

# Switch to the default mamba environment
function _default_menv()
{
  if [[ -n "$AUTOSWITCH_DEFAULT_MAMBAENV" ]]; then
     _maybeactivate "$AUTOSWITCH_DEFAULT_MAMBAENV"
  elif [[ -n "$CONDA_DEFAULT_ENV" ]]; then
      mamba deactivate
  fi
}


# remove mamba environment for current directory
function rmmenv()
{
  if [[ -f ".menv" ]]; then

    menv_name="$(<.menv)"

    # detect if we need to switch mamba environment first
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        current_menv="$(basename $CONDA_DEFAULT_ENV)"
        if [[ "$current_menv" = "$menv_name" ]]; then
            _default_menv
        fi
    fi

    mamba env remove --name "$menv_name"
    rm ".menv"
  else
    printf "No .menv file in the current directory!\n"
  fi
}


# helper function to create a mamba environment for the current directory
function mkmenv()
{
  if [[ -f ".menv" ]]; then
    printf ".menv file already exists. If this is a mistake use the rmmenv command\n"
  else
    menv_name="$(basename $PWD)"
    mamba create --name "$menv_name" $@
    mamba activate "$menv_name"

    setopt nullglob
    for requirements in *requirements.txt
    do
      printf "Found a %s file. Install using pip? [y/N]: " "$requirements"
      read ans

      if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
        pip install -r "$requirements"
      fi
    done

    for requirements in *requirements.yml
    do
      printf "Found a %s file. Install using mamba? [y/N]: " "$requirements"
      read ans

      if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
        mamba env update -f "$requirements"
      fi
    done

    if [[ -f "environment.yml" ]]; then
      for requirements in *environment.yml
      do
        printf "Found a %s file. Install using mamba? [y/N]: " "$requirements"
        read ans

        if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
          mamba env update -f "$requirements"
        fi
      done
    else
      menv_name="$(basename $PWD)"
      echo "name: $menv_name" > environment.yml
      cat $SCRIPT_DIR/environment.yml >> environment.yml
      printf "Built a base %s file. Install using mamba? [y/N]: " "$requirements"
      read ans

      if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
        mamba env update
      fi
    fi


    printf "$menv_name\n" > ".menv"
    chmod 600 .menv
    AUTOSWITCH_PROJECT="$PWD"
  fi
}

if [[ -z "$DISABLE_AUTO_SWITCH_MAMBAENV" ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook -D chpwd check_menv
    add-zsh-hook chpwd check_menv

    check_menv
fi