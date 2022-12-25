#shellcheck shell=sh
set -eu

Describe 'Dependency'
  Describe 'ipfs:'
    It 'is available'
      When run ipfs --help
      The output should include "ipfs"
      The status should be success
      The stderr should equal ""
    End
  End
End

Describe 'Astroport'
  Describe 'template_register'
    Include ./tools/template.sh
    It 'creates host html register page'
      When call template_register
      The output should include $(hostname)
      The status should be success
      The stderr should equal ""
    End
  End
End
