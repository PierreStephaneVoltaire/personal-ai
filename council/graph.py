import re
import yaml
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END
from client import LiteLLMClient

class CouncilState(TypedDict):
    messages: list
    next_speaker: str
    current_speaker: str
    resolved: bool
    turn_count: int

def load_config():
    with open("/app/config/models.yaml", "r") as f:
        models_config = yaml.safe_load(f)
    with open("/app/config/personalities.yaml", "r") as f:
        personalities_config = yaml.safe_load(f)
    return models_config, personalities_config

def extract_routing_block(content: str):
    pattern = r"```routing\s*\n(.*?)\n```"
    match = re.search(pattern, content, re.DOTALL | re.IGNORECASE)
    if not match:
        return None, content

    routing_block = match.group(1)
    clean_content = re.sub(pattern, "", content, flags=re.DOTALL | re.IGNORECASE).strip()

    next_speaker = None
    resolved = False

    for line in routing_block.split("\n"):
        line = line.strip()
        if line.startswith("NEXT:"):
            next_speaker = line.split(":", 1)[1].strip()
        elif line.startswith("RESOLVED:"):
            resolved_str = line.split(":", 1)[1].strip().lower()
            resolved = resolved_str == "true"

    return {"next": next_speaker, "resolved": resolved}, clean_content

def create_member_node(member_key: str, models_config: dict, personalities_config: dict):
    async def node_func(state: CouncilState) -> CouncilState:
        client = LiteLLMClient()

        model_config = models_config[member_key]
        personality = personalities_config[member_key]

        system_message = {"role": "system", "content": personality["system_prompt"]}
        messages = [system_message] + state["messages"]

        response_content = await client.chat(
            model=model_config["model_id"],
            messages=messages,
            max_tokens=model_config["max_tokens"],
            temperature=model_config["temperature"]
        )

        routing_info, clean_content = extract_routing_block(response_content)

        next_speaker = "none"
        resolved = False

        if routing_info:
            next_speaker = routing_info.get("next", "none")
            # Only the manager can end the conversation
            if model_config["role"] == "manager":
                resolved = routing_info.get("resolved", False)
            # Non-managers' RESOLVED is ignored

        new_message = {
            "role": "assistant",
            "content": f"[{personality['name']}]: {clean_content}",
            "name": member_key
        }

        return {
            "messages": state["messages"] + [new_message],
            "next_speaker": next_speaker,
            "current_speaker": member_key,
            "resolved": resolved,
            "turn_count": state["turn_count"] + 1
        }

    return node_func

def route_after_member(state: CouncilState) -> str:
    MAX_TURNS = 20

    # Hard cap: prevent infinite loops
    if state["turn_count"] >= MAX_TURNS:
        return "end"

    if state["resolved"] or state["next_speaker"] == "none":
        return "end"

    if state["next_speaker"] == "self":
        return state["current_speaker"]

    models_config, _ = load_config()
    if state["next_speaker"] in models_config:
        return state["next_speaker"]

    manager_key = None
    for key, config in models_config.items():
        if config["role"] == "manager":
            manager_key = key
            break

    return manager_key if manager_key else "end"

def create_council_graph():
    models_config, personalities_config = load_config()

    graph = StateGraph(CouncilState)

    manager_key = None
    for member_key, model_config in models_config.items():
        node_func = create_member_node(member_key, models_config, personalities_config)
        graph.add_node(member_key, node_func)

        if model_config["role"] == "manager":
            manager_key = member_key

    if not manager_key:
        raise ValueError("No manager found in council configuration")

    graph.set_entry_point(manager_key)

    for member_key in models_config.keys():
        graph.add_conditional_edges(
            member_key,
            route_after_member,
            {
                **{key: key for key in models_config.keys()},
                "end": END
            }
        )

    return graph.compile()
