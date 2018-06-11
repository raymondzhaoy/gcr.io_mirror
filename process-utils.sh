_PROCESS_PIPE_NAME="/tmp/$(cat /proc/sys/kernel/random/uuid)"
_PROCESS_PIPE_ID=10

function _create_pipe()
{

  mkfifo ${_PROCESS_PIPE_NAME}
  eval exec "${_PROCESS_PIPE_ID}""<>${_PROCESS_PIPE_NAME}"

  for ((i=0; i< $1; i++))
  do
    echo >&${_PROCESS_PIPE_ID}
  done
}

function process_init()
{
  _create_pipe $1
}

function _delete_pipe
{
  eval "exec ${_PROCESS_PIPE_ID}>&-;exec ${_PROCESS_PIPE_ID}<&-;rm -rf ${_PROCESS_PIPE_NAME}"
}

function _clean_up
{
  _delete_pipe

  kill 0
  kill -9 $$
}

trap _clean_up SIGINT SIGHUP SIGTERM SIGKILL

function process_run()
{
  cmd=$1
  
  if [ -z "$cmd" ]; then
    echo "please input command to run"
    _delete_pipe
    exit 1
  fi
  
  read -u${_PROCESS_PIPE_ID}
  {
    $cmd
    echo >&${_PROCESS_PIPE_ID}
  }&
}
 