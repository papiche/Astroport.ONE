#shellcheck shell=sh

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
  Describe 'tools/my.sh'
  Include ./tools/my.sh
    It 'does my env variables'
      myhost() {
        echo $myHOST
        echo $myIPFS
      }
      When call myhost
      The output should include astroport.
      The output should include ipfs.
      The status should be success
      The stderr should equal ""
    End
  End
End
