module Bash
  def bash(script)
    command = "bash -c 'set -eo pipefail; #{script.gsub("'", "\\'")}'"
    success = system(command)
    raise("failed") unless success
  end
end