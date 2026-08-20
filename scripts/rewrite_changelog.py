import sys
import json
import random
import httpx
import asyncio
from datetime import datetime

API_KEYS = [
    "csk-w5ewfe5ym9dxxxrnxtw6m38d8vyv6rthcff8xptxm43dhpn6",
    "csk-p489t6vtm6etft3yjt5jpc4vjdmc5jtk58nxn5jy9nn6nkh2",
    "csk-p5cc4dfjh438jr2cff4rr36y6ndm395rc2335v6p4n2en286",
    "csk-e2jxpn326w432mrdrv8ehmrd25x5tjx8fdk3j34w88pr2emd",
    "csk-khdxd2mjx2pr54jk2vkjehkmnm956dmvecjpc5kwhfnm2mm4"
]

async def rewrite_changelog(raw_file, out_file, version):
    with open(raw_file, 'r', encoding='utf-8') as f:
        raw_notes = f.read().strip()
        
    if not raw_notes:
        print("Raw notes are empty. Skipping rewrite.")
        with open(out_file, 'w', encoding='utf-8') as f:
            f.write(f"Changelog for FinDuo v{version}\n\nNo changes provided.")
        return

    prompt = f"""You are a technical writer for the FinDuo app. 
Rewrite the following raw development notes into a clean, professional changelog.
CRITICAL RULE: You MUST NOT include, rewrite, or expose any personal, private, or PII information.

Return ONLY a valid JSON object matching this exact structure:
{{
  "version": "v{version}",
  "date": "{datetime.now().strftime('%B %d, %Y')}",
  "features": ["feature 1", "feature 2"],
  "fixes": ["fix 1", "fix 2"]
}}

Raw notes:
{raw_notes}
"""

    key = random.choice(API_KEYS)
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "llama3.1-8b", # Faster, good enough for formatting
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 1024,
    }
    
    url = "https://api.cerebras.ai/v1/chat/completions"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(url, headers=headers, json=data, timeout=30.0)
            response.raise_for_status()
            result = response.json()
            cleaned_response = result["choices"][0]["message"]["content"].strip()
            
            if cleaned_response.startswith('```json'):
                cleaned_response = cleaned_response[7:]
            elif cleaned_response.startswith('```'):
                cleaned_response = cleaned_response[3:]
            if cleaned_response.endswith('```'):
                cleaned_response = cleaned_response[:-3]
                
            cleaned_response = cleaned_response.strip()
            
            # Save the clean JSON directly to the output file
            with open(out_file, 'w', encoding='utf-8') as f:
                f.write(cleaned_response)
                
            # Inject it into the Flutter App's Dart code
            import os
            import re
            
            # The out_file path is typically c:\EST\FinDuo\APK\changelog-vXX.txt
            # We want to go to c:\EST\FinDuo\frontend\lib\screens\changelog_screen.dart
            base_dir = os.path.dirname(os.path.dirname(out_file))
            dart_file = os.path.join(base_dir, "frontend", "lib", "screens", "changelog_screen.dart")
            
            if os.path.exists(dart_file):
                with open(dart_file, 'r', encoding='utf-8') as f:
                    dart_code = f.read()
                    
                target = "final List<Map<String, dynamic>> _hardcodedLogs = ["
                if target in dart_code:
                    replacement = target + "\n    " + cleaned_response + ","
                    dart_code = dart_code.replace(target, replacement, 1)
                    with open(dart_file, 'w', encoding='utf-8') as f:
                        f.write(dart_code)
                    print(f"Successfully injected changelog into {dart_file}")
                else:
                    print("Could not find _hardcodedLogs list in dart file.")
            else:
                print(f"Could not find dart file at {dart_file}")
                
            print("Successfully rewrote changelog with Cerebras AI.")
    except Exception as e:
        print(f"Error calling Cerebras API: {str(e)}")
        # Fallback to saving raw notes
        with open(out_file, 'w', encoding='utf-8') as f:
            f.write(f"Changelog for FinDuo v{version}\n\n{raw_notes}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python rewrite_changelog.py <raw_file> <out_file> <version>")
        sys.exit(1)
        
    asyncio.run(rewrite_changelog(sys.argv[1], sys.argv[2], sys.argv[3]))
