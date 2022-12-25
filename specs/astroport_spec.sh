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
  Describe 'tools/myhost.sh'
    Include ./tools/myhost.sh
    myhost() {
      echo $myHOST
      echo $myIPFS
    }
    It 'hydrates host env variables'
      When call myhost
      The output should include astroport.
      The output should include ipfs.
      The status should be success
      The stderr should equal ""
    End
  End
  Describe 'tools/template.sh'
    Include ./tools/myhost.sh
    Include ./tools/template.sh
    It 'creates host html register page'
      When call template_register
      The output should include $(hostname)
      The status should be success
      The stderr should equal ""
    End
  End
End
