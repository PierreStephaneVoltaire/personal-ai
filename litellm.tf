resource "kubernetes_persistent_volume_claim" "litellm_data" {
  metadata {
    name      = "litellm-data-pvc"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_config_map" "litellm_config" {
  metadata {
    name      = "litellm-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      general_settings = {
        store_model_in_db           = true
        store_prompts_in_spend_logs = true
        default_fallbacks           = ["kimi-k2.5"]
        cache                       = true
        cache_params                = { type = "local" }
        master_key                  = "os.environ/LITELLM_MASTER_KEY"
      }
      router_settings = {
        enable_tag_filtering    = true
        routing_strategy        = "simple-shuffle"
        tag_filtering_match_any = false
      }
      litellm_settings = {
        mcp_aliases = {
          "fs"         = "filesystem"
          "aws"        = "aws_docs"
          "terraform"  = "terraform"
          "eks"        = "eks"
          "ecs"        = "ecs"
          "serverless" = "serverless"
          "k8s"        = "kubernetes"
          "cost"       = "cost_explorer"
          "cloudwatch" = "cloudwatch"
          "bedrock"    = "bedrock"
          "pricing"    = "pricing"
          "billing"    = "billing"
          "iac"        = "iac"
          "core"       = "core"
        }
        enable_semantic_cache = true
        cache_ttl             = 3600
      }
      mcp_servers = merge({
        for key, val in var.mcp_servers : key => {
          url       = "http://mcp-server-${replace(key, "_", "-")}.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local:${val.port}/sse"
          transport = "sse"
          startup   = false
        }
      }, var.additional_mcps)
      model_list = concat(
        flatten([

          for model in var.litellm_models : flatten(



            [

              # Special case: if classifier tag is present, create "classifier" group entries
              contains(model.tags, "classifier") ? [
                {
                  model_name = "classifier"
                  litellm_params = {
                    model       = "openrouter/${model.model_id}"
                    api_base    = "https://openrouter.ai/api/v1"
                    api_key     = "os.environ/OPENROUTER_API_KEY"
                    max_tokens  = model.max_tokens
                    temperature = model.temperature
                    top_p       = try(model.top_p, 0.9)
                  }
                }
              ] : [],

              # Generate ALL qualifying groups for each tier - models can appear in multiple groups
              # This creates duplicate entries for load balancing when a model qualifies for multiple groups
              flatten([
                for tier in [for t in ["tier1", "tier2", "tier3", "tier4"] : t if contains(model.tags, t)] :
                [
                  for item in [
                    # TOOLS-REQUIRED FLOWS (models WITH tools tag)
                    # breakglass-tier4: Tier4 with tools tag
                    tier == "tier4" && contains(model.tags, "tools") ? {
                      model_name = "breakglass-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # architect-role-tier4: Tier4 with tools + thinking (NOT programming)
                    tier == "tier4" && contains(model.tags, "tools") && contains(model.tags, "thinking") && !contains(model.tags, "programming") ? {
                      model_name = "architect-role-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # python-coder-tier4: Tier4 with tools + programming
                    tier == "tier4" && contains(model.tags, "tools") && contains(model.tags, "programming") ? {
                      model_name = "python-coder-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # python-coder-tier3: Tier3 with tools + programming
                    tier == "tier3" && contains(model.tags, "tools") && contains(model.tags, "programming") ? {
                      model_name = "python-coder-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # devops-engineer-tier3: Tier3 with tools + general (NOT programming)
                    tier == "tier3" && contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "devops-engineer-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # python-coder-tier2: Tier2 with tools + programming
                    tier == "tier2" && contains(model.tags, "tools") && contains(model.tags, "programming") ? {
                      model_name = "python-coder-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # command-executor-tier2: Tier2 with tools + general (NOT programming)
                    tier == "tier2" && contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "command-executor-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # researcher-tier2: Tier2 with tools + general (NOT programming) - same as command-executor but for research
                    tier == "tier2" && contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "researcher-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # NO-TOOLS FLOWS (models WITHOUT tools tag)
                    # social-tier1: Tier1 with general OR social OR creative tags (NO tools)
                    tier == "tier1" && !contains(model.tags, "tools") && (contains(model.tags, "general") || contains(model.tags, "social") || contains(model.tags, "creative")) ? {
                      model_name = "social-tier1"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # simple-tier1: Tier1 with general tag (NO tools)
                    tier == "tier1" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "simple-tier1"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # proofreader-tier1: Tier1 with general tag (NO tools) - same as simple-tier1
                    tier == "tier1" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "proofreader-tier1"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # simple-tier2: Tier2 with general + programming tags (NO tools)
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") && contains(model.tags, "programming") ? {
                      model_name = "simple-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # shell-tier2: Tier2 with general tag, NOT programming tag (NO tools)
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "shell-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # shell-commander-tier2: Tier2 with general tag (may or may not have tools)
                    tier == "tier2" && contains(model.tags, "general") ? {
                      model_name = "shell-commander-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # simple-websearch-tier2: Tier2 with websearch tag
                    tier == "tier2" && contains(model.tags, "websearch") ? {
                      model_name = "simple-websearch-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # simple-websearch-tier3: Tier3 with websearch tag
                    tier == "tier3" && contains(model.tags, "websearch") ? {
                      model_name = "simple-websearch-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # simple-websearch-tier4: Tier4 with websearch tag
                    tier == "tier4" && contains(model.tags, "websearch") ? {
                      model_name = "simple-websearch-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # backcasting-tier2: Tier2 with thinking tag (NO tools)
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "backcasting-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # delphi-method-tier2: Tier2 with thinking tag (NO tools) - same as backcasting
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "delphi-method-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # branch-tier3: Tier3 with thinking tag (NO tools)
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "branch-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # backcasting-tier3: Tier3 with thinking tag (NO tools) - same as branch-tier3
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "backcasting-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # delphi-method-tier3: Tier3 with thinking tag (NO tools) - same as branch-tier3
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "delphi-method-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # consensus-tier3: Tier3 with general tag (NO tools)
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "consensus-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # angel-devil-tier3: Tier3 with general tag (NO tools) - same as consensus-tier3
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "angel-devil-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # adversarial-validation-tier3: Tier3 with general tag (NO tools) - same as consensus-tier3
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "adversarial-validation-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # chain-of-verification-tier3: Tier3 with general tag (NO tools) - same as consensus-tier3
                    tier == "tier3" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "chain-of-verification-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # consensus-tier2: Tier2 with general tag (NO tools)
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "consensus-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # angel-devil-tier2: Tier2 with general tag (NO tools) - same as consensus-tier2
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "angel-devil-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # adversarial-validation-tier2: Tier2 with general tag (NO tools) - same as consensus-tier2
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "adversarial-validation-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # chain-of-verification-tier2: Tier2 with general tag (NO tools) - same as consensus-tier2
                    tier == "tier2" && !contains(model.tags, "tools") && contains(model.tags, "general") ? {
                      model_name = "chain-of-verification-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # dialectic-tier2: Tier2 with general OR websearch tags (NO tools)
                    tier == "tier2" && !contains(model.tags, "tools") && (contains(model.tags, "general") || contains(model.tags, "websearch")) ? {
                      model_name = "dialectic-tier2"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # branch-tier4: Tier4 with thinking tag (NO tools)
                    tier == "tier4" && !contains(model.tags, "tools") && contains(model.tags, "thinking") ? {
                      model_name = "branch-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # architecture-tier4: Tier4 with thinking AND programming tags (NO tools)
                    tier == "tier4" && !contains(model.tags, "tools") && contains(model.tags, "thinking") && contains(model.tags, "programming") ? {
                      model_name = "architecture-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # code-reviewer-tier3: Tier3 with tools + programming
                    tier == "tier3" && contains(model.tags, "tools") && contains(model.tags, "programming") ? {
                      model_name = "code-reviewer-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # code-reviewer-tier4: Tier4 with tools + programming
                    tier == "tier4" && contains(model.tags, "tools") && contains(model.tags, "programming") ? {
                      model_name = "code-reviewer-tier4"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # documentation-writer-tier3: Tier3 with tools + general (NOT programming)
                    tier == "tier3" && contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "documentation-writer-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null,

                    # dba-tier3: Tier3 with tools + general (NOT programming) - same as documentation-writer
                    tier == "tier3" && contains(model.tags, "tools") && contains(model.tags, "general") && !contains(model.tags, "programming") ? {
                      model_name = "dba-tier3"
                      litellm_params = {
                        model       = "openrouter/${model.model_id}"
                        api_base    = "https://openrouter.ai/api/v1"
                        api_key     = "os.environ/OPENROUTER_API_KEY"
                        max_tokens  = model.max_tokens
                        temperature = model.temperature
                        top_p       = try(model.top_p, 0.9)
                      }
                    } : null
                  ] : item if item != null
                ]
              ])
          ])
        ]), # Default entry for each model

        [
          for model in var.litellm_models : {
            model_name = model.model_name
            litellm_params = {
              model    = "openrouter/${model.model_id}"
              api_base = "https://openrouter.ai/api/v1"
              api_key  = "os.environ/OPENROUTER_API_KEY"
            }
          }
        ]
      )
    })
  }
}

resource "kubernetes_deployment" "litellm" {
  lifecycle {
    replace_triggered_by = [kubernetes_config_map.litellm_config]
  }
  metadata {
    name      = "litellm"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app = "litellm"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "litellm"
      }
    }
    template {
      metadata {
        labels = {
          app = "litellm"
        }
      }
      spec {
        node_selector = {
          "workload-type" = "ai-services"
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "ai-services"
          effect   = "NoSchedule"
        }

        container {
          name              = "litellm"
          image             = "ghcr.io/berriai/litellm:main-latest"
          image_pull_policy = "IfNotPresent"
          args              = ["--config", "/app/config.yaml", "--port", "4000"]

          port {
            container_port = 4000
            protocol       = "TCP"
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "LITELLM_DATABASE_URL"
              }
            }
          }
          env {
            name = "OPENROUTER_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "OPENROUTER_API_KEY"
              }
            }
          }
          env {
            name  = "OPENAI_API_KEY"
            value = "dummy-key"
          }

          env {
            name = "LITELLM_MASTER_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "LITELLM_MASTER_KEY"
              }
            }
          }

          env {
            name = "UI_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "UI_USERNAME"
              }
            }
          }

          env {
            name = "UI_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "UI_PASSWORD"
              }
            }
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "10m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health/liveliness"
              port   = 4000
              scheme = "HTTP"
              http_header {
                name  = "Authorization"
                value = "Bearer ${data.aws_ssm_parameter.litellm_master_key.value}"
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 1
          }

          readiness_probe {
            http_get {
              path   = "/health/readiness"
              port   = 4000
              scheme = "HTTP"
              http_header {
                name  = "Authorization"
                value = "Bearer ${data.aws_ssm_parameter.litellm_master_key.value}"
              }
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 1
          }

          volume_mount {
            mount_path = "/app/config.yaml"
            name       = "config"
            sub_path   = "config.yaml"
          }
          volume_mount {
            mount_path = "/app/data"
            name       = "litellm-data"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.litellm_config.metadata[0].name
          }
        }
        volume {
          name = "litellm-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.litellm_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "litellm" {
  metadata {
    name      = "litellm"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
  spec {
    selector = {
      app = "litellm"
    }
    port {
      port        = 4000
      target_port = 4000
    }
    type = "ClusterIP"
  }
}
