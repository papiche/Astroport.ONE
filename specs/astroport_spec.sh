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
    It 'does my env variables'
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
    It 'does host html register page'
      When call template_register
      The stdout should include $(hostname)
      The stdout should include $IPFSNODEID
      The stdout should include $myASTROPORT
      The stdout should include $myIPFS
      The status should be success
      The stderr should equal ""
    End
  End
End
