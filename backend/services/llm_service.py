import google.generativeai as genai
from backend.config import settings

genai.configure(api_key=settings.GEMINI_API_KEY)
model = genai.GenerativeModel("gemini-1.5-flash")

SYSTEM_PROMPT = """
You are an expert MQL5 programmer for MetaTrader 5.
When given a trading strategy description, generate a complete, 
compilable MQL5 Expert Advisor script.

Rules:
- Always include proper #property directives at the top
- Always implement OnInit(), OnDeinit(), OnTick() functions
- Use proper MQL5 syntax — not MQL4
- Include input parameters for key strategy values
- Add basic risk management (stop loss, take profit)
- Add comments explaining the logic
- Return ONLY the raw MQL5 code, no markdown, no explanation

The script must compile with 0 errors in MetaEditor.
"""

async def generate_mql5_script(user_prompt: str, job_id: str) -> tuple[str, str]:
    script_name = f"strategy_{str(job_id)[:8]}"
    
    prompt = f"""
    {SYSTEM_PROMPT}
    
    Generate a complete MQL5 Expert Advisor for this strategy:
    {user_prompt}
    
    Script name should be: {script_name}
    Use #property script_name "{script_name}.mq5"
    """
    
    response = model.generate_content(prompt)
    script_content = response.text.strip()
    
    # Clean up any markdown code blocks if LLM adds them
    if script_content.startswith("```"):
        lines = script_content.split("\n")
        script_content = "\n".join(lines[1:-1])
        if script_content.startswith("mql5\n"):
            script_content = script_content[5:]
    
    return script_content, f"{script_name}.mq5"
