#shellcheck shell=sh
# specs/astrosystemctl_spec.sh — Tests unitaires fonctions pures de astrosystemctl

Describe 'astrosystemctl'

  # Setup : charge l'environnement et source les fonctions sans exécuter le dispatch
  BeforeAll '_astro_spec_setup'
  AfterAll  '_astro_spec_teardown'

  _astro_spec_setup() {
    MY_PATH="$(cd "$(dirname "$0")/../tools" 2>/dev/null && pwd || cd "./tools" && pwd)"
    export MY_PATH
    export ASTROSYSTEMCTL_TEST=1
    export IPFSNODEID="${IPFSNODEID:-QmTestNodeSpec000000000000000}"
    # shellcheck source=/dev/null
    . "${MY_PATH}/astrosystemctl.sh" 2>/dev/null
  }

  _astro_spec_teardown() {
    unset ASTROSYSTEMCTL_TEST
  }

  # ── power_label ────────────────────────────────────────────────────────────

  Describe 'power_label'
    It 'score 0 → Light'
      When call power_label 0
      The output should include "Light"
    End
    It 'score 5 → Light'
      When call power_label 5
      The output should include "Light"
    End
    It 'score 10 → Light (boundary)'
      When call power_label 10
      The output should include "Light"
    End
    It 'score 11 → Standard (boundary)'
      When call power_label 11
      The output should include "Std"
    End
    It 'score 40 → Standard (boundary)'
      When call power_label 40
      The output should include "Std"
    End
    It 'score 41 → Brain (boundary)'
      When call power_label 41
      The output should include "Brain"
    End
    It 'score 100 → Brain'
      When call power_label 100
      The output should include "Brain"
    End
  End

  # ── _svc_to_hb_key ────────────────────────────────────────────────────────

  Describe '_svc_to_hb_key'
    It 'open-webui → open_webui'
      When call _svc_to_hb_key "open-webui"
      The output should equal "open_webui"
    End
    It 'dify.ai → dify (supprime .ai)'
      When call _svc_to_hb_key "dify.ai"
      The output should equal "dify"
    End
    It 'ollama → ollama (inchangé)'
      When call _svc_to_hb_key "ollama"
      The output should equal "ollama"
    End
    It 'nextcloud-aio → nextcloud_aio'
      When call _svc_to_hb_key "nextcloud-aio"
      The output should equal "nextcloud_aio"
    End
    It 'webtop-http → webtop_http'
      When call _svc_to_hb_key "webtop-http"
      The output should equal "webtop_http"
    End
  End

  # ── get_service_category ──────────────────────────────────────────────────

  Describe 'get_service_category'
    It 'ollama → IA'
      When call get_service_category "ollama"
      The output should include "IA"
    End
    It 'comfyui → IA'
      When call get_service_category "comfyui"
      The output should include "IA"
    End
    It 'open-webui → IA'
      When call get_service_category "open-webui"
      The output should include "IA"
    End
    It 'icecast → Audio'
      When call get_service_category "icecast"
      The output should include "Audio"
    End
    It 'ssh → Sys'
      When call get_service_category "ssh"
      The output should include "Sys"
    End
    It 'nextcloud → Sys'
      When call get_service_category "nextcloud"
      The output should include "Sys"
    End
    It 'service inconnu → App'
      When call get_service_category "monservice"
      The output should include "App"
    End
  End

  # ── _group_to_install_script ──────────────────────────────────────────────

  Describe '_group_to_install_script'
    It 'gpu-ai → install_gpu_ai.sh'
      When call _group_to_install_script "gpu-ai" "/astro"
      The output should include "install_gpu_ai.sh"
    End
    It 'ai-company → install-ai-company.docker.sh'
      When call _group_to_install_script "ai-company" "/astro"
      The output should include "install-ai-company.docker.sh"
    End
    It 'youtube-antibot → install_youtube_antibot.sh'
      When call _group_to_install_script "youtube-antibot" "/astro"
      The output should include "install_youtube_antibot.sh"
    End
    It 'powerjoular → install_powerjoular.sh'
      When call _group_to_install_script "powerjoular" "/astro"
      The output should include "install_powerjoular.sh"
    End
    It 'prometheus → install_prometheus.sh'
      When call _group_to_install_script "prometheus" "/astro"
      The output should include "install_prometheus.sh"
    End
    It 'leann → install_leann.sh'
      When call _group_to_install_script "leann" "/astro"
      The output should include "install_leann.sh"
    End
    It 'zelkova → install_zelkova.sh'
      When call _group_to_install_script "zelkova" "/astro"
      The output should include "install_zelkova.sh"
    End
    It 'nextcloud → install_nextcloud.sh'
      When call _group_to_install_script "nextcloud" "/astro"
      The output should include "install_nextcloud.sh"
    End
    It 'core → vide (pas de script)'
      When call _group_to_install_script "core" "/astro"
      The output should equal ""
    End
    It '- → vide (pas de script)'
      When call _group_to_install_script "-" "/astro"
      The output should equal ""
    End
    It 'inconnu → install_inconnu.sh (pattern générique)'
      When call _group_to_install_script "inconnu" "/astro"
      The output should include "install_inconnu.sh"
    End
  End

End
