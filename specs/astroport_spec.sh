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
    It 'does host html register page'
      When call myHtml
      The stdout should include $(hostname)
      The stdout should include $IPFSNODEID
      The stdout should include $myASTROPORT
      The stdout should include $myIPFS
      The status should be success
      The stderr should equal ""
    End
    It 'does localhost html register page'
      isLAN=true
      When call myHtml
      The stdout should include "input name='salt' value=''"
      The stdout should include "input name='pepper' value=''"
      The status should be success
      The stderr should equal ""
    End
  End
End
