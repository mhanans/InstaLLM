import os
import gradio as gr
from llama_cpp import Llama
from typing import List, Dict
import subprocess
import json
import sys

# Custom CSS for styling
custom_css = """
:root {
    --primary-color: #4a90e2;
    --secondary-color: #2c3e50;
    --accent-color: #e74c3c;
    --background-color: #f5f6fa;
    --text-color: #2c3e50;
    --border-color: #dcdde1;
}

.gradio-container {
    background: var(--background-color) !important;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif !important;
}

/* Title container styling */
.title-container {
    background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)) !important;
    padding: 2rem !important;
    border-radius: 10px !important;
    margin-bottom: 2rem !important;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1) !important;
    text-align: center !important;
}

.title-container h1 {
    color: white !important;
    font-size: 2.5rem !important;
    margin: 0 !important;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3) !important;
}

.title-container h2 {
    color: rgba(255, 255, 255, 0.9) !important;
    margin: 0.5rem 0 0 0 !important;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.2) !important;
}

.title-container p {
    color: rgba(255, 255, 255, 0.9) !important;
    margin: 0.5rem 0 0 0 !important;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.2) !important;
}

.gradio-interface {
    max-width: 1200px !important;
    margin: 0 auto !important;
    padding: 2rem !important;
}

.gradio-row {
    background: white !important;
    border-radius: 10px !important;
    padding: 1.5rem !important;
    margin-bottom: 1.5rem !important;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05) !important;
}

.gradio-button {
    background: var(--primary-color) !important;
    color: white !important;
    border: none !important;
    padding: 0.75rem 1.5rem !important;
    border-radius: 5px !important;
    font-weight: 600 !important;
    transition: all 0.3s ease !important;
}

.gradio-button:hover {
    background: var(--secondary-color) !important;
    transform: translateY(-2px) !important;
}

.gradio-textbox {
    border: 2px solid var(--border-color) !important;
    border-radius: 5px !important;
    padding: 1rem !important;
    font-size: 1rem !important;
    color: var(--text-color) !important;
    background: white !important;
}

.gradio-textbox:focus {
    border-color: var(--primary-color) !important;
    box-shadow: 0 0 0 2px rgba(74, 144, 226, 0.2) !important;
}

.gradio-dropdown {
    border: 2px solid var(--border-color) !important;
    border-radius: 5px !important;
    padding: 0.5rem !important;
    color: var(--text-color) !important;
    background: white !important;
}

.gradio-dropdown option {
    color: var(--text-color) !important;
    background: white !important;
}

.gradio-footer {
    text-align: center !important;
    padding: 1rem !important;
    color: var(--text-color) !important;
    font-size: 0.9rem !important;
    margin-top: 2rem !important;
}
"""

class InstaLLM:
    def __init__(self, models_dir: str = "models"):
        self.models_dir = models_dir
        self.models: Dict[str, Llama] = {}
        self.available_models = []
        self.conversation_history: Dict[str, List[Dict[str, str]]] = {}
        self.bitnet_models = {}  # Store BitNet model paths
        
        # Create models directory if it doesn't exist
        if not os.path.exists(models_dir):
            os.makedirs(models_dir)
        
        # Load available models
        self._load_available_models()
        
        # System prompt for better responses
        self.system_prompt = """You are InstaLLM, a helpful and professional AI assistant. 
Your responses should be:
1. Clear and concise
2. Focused on the user's request
3. Professional and informative
4. Well-structured and easy to read

Always maintain a helpful and professional tone. If you're unsure about something, say so rather than making things up."""
    
    def _load_available_models(self):
        """Load all .gguf files from the models directory"""
        self.available_models = []
        self.bitnet_models = {}
        
        for file in os.listdir(self.models_dir):
            if file.endswith(".gguf"):
                # Check if it's a BitNet model
                if "bitnet" in file.lower():
                    self.bitnet_models[file] = os.path.join(self.models_dir, file)
                else:
                    self.available_models.append(file)
        
        print(f"Available models: {self.available_models}")
        print(f"Available BitNet models: {list(self.bitnet_models.keys())}")
        
        # Return all available models for the dropdown
        return self.available_models + list(self.bitnet_models.keys())
    
    def load_model(self, model_name: str) -> str:
        """Load a specific model into memory"""
        if not model_name:
            return "Please select a model first!"
            
        if model_name not in self.available_models and model_name not in self.bitnet_models:
            return f"Model {model_name} not found!"
        
        try:
            if model_name in self.bitnet_models:
                # Initialize BitNet model
                model_path = self.bitnet_models[model_name]
                if not os.path.exists(model_path):
                    return f"Error: BitNet model file not found at {model_path}"
                
                self.models[model_name] = {
                    "type": "bitnet",
                    "path": model_path
                }
                print(f"Loaded BitNet model: {model_name} from {model_path}")
                return f"BitNet model {model_name} loaded successfully!"
            else:
                # Initialize regular LLM model
                model_path = os.path.join(self.models_dir, model_name)
                if not os.path.exists(model_path):
                    return f"Error: Model file not found at {model_path}"
                
                self.models[model_name] = {
                    "type": "llama",
                    "model": Llama(
                        model_path=model_path,
                        n_ctx=2048,
                        n_threads=4
                    )
                }
                # Initialize conversation history for this model
                self.conversation_history[model_name] = []
                print(f"Loaded LLM model: {model_name} from {model_path}")
                return f"Model {model_name} loaded successfully!"
        except Exception as e:
            error_msg = f"Error loading model {model_name}: {str(e)}"
            print(error_msg)
            return error_msg
    
    def generate_response(self, model_name: str, prompt: str) -> str:
        """Generate response from the selected model"""
        if not model_name:
            return "Please select a model first!"
            
        if model_name not in self.models:
            return "Please load the model first!"
        
        try:
            # Add the new user message to conversation history
            if model_name not in self.conversation_history:
                self.conversation_history[model_name] = []
            self.conversation_history[model_name].append({"role": "user", "content": prompt})
            
            # Build the full conversation context
            conversation_context = f"""<|system|>
{self.system_prompt}
</|system|>
"""
            # Add conversation history
            for message in self.conversation_history[model_name]:
                if message["role"] == "user":
                    conversation_context += f"""<|user|>
{message['content']}
</|user|>
"""
                else:
                    conversation_context += f"""<|assistant|>
{message['content']}
</|assistant|>
"""
            # Add the current assistant tag
            conversation_context += "<|assistant|>\n"
            
            model_info = self.models[model_name]
            
            if model_info["type"] == "bitnet":
                # Run BitNet inference with enhanced error handling
                try:
                    # Verify run_inference.py exists
                    if not os.path.exists("run_inference.py"):
                        return "Error: run_inference.py not found. Please ensure it's in the same directory as app.py"
                    
                    # Run inference with full path to Python
                    python_path = sys.executable
                    cmd = [
                        python_path,
                        "run_inference.py",
                        "-m", model_info["path"],
                        "-p", conversation_context,
                        "-cnv",
                        "-t", "4",  # Use 4 threads
                        "-c", "2048",  # Context size
                        "-temp", "0.7"  # Temperature
                    ]
                    
                    print(f"Running BitNet command: {' '.join(cmd)}")  # Debug output
                    
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    
                    if result.returncode != 0:
                        error_msg = f"BitNet inference error (code {result.returncode}):\n"
                        error_msg += f"STDOUT: {result.stdout}\n"
                        error_msg += f"STDERR: {result.stderr}"
                        print(error_msg)  # Debug output
                        return error_msg
                    
                    response_text = result.stdout.strip()
                    if not response_text:
                        return "Error: BitNet returned empty response"
                    
                    # Add the assistant's response to conversation history
                    self.conversation_history[model_name].append({"role": "assistant", "content": response_text})
                    
                    return response_text
                    
                except Exception as e:
                    error_msg = f"Error running BitNet inference: {str(e)}\n"
                    error_msg += f"Python path: {python_path}\n"
                    error_msg += f"Model path: {model_info['path']}"
                    print(error_msg)  # Debug output
                    return error_msg
            else:
                # Generate response with proper formatting
                response = model_info["model"](
                    conversation_context,
                    max_tokens=2000,
                    temperature=0.7,
                    top_p=0.9,
                    stop=["</|assistant|>", "<|user|>", "<|system|>"]
                )
                response_text = response['choices'][0]['text'].strip()
                response_text = response_text.replace("</|assistant|>", "").strip()
                
                # Add the assistant's response to conversation history
                self.conversation_history[model_name].append({"role": "assistant", "content": response_text})
                
                return response_text
        except Exception as e:
            error_msg = f"Error generating response: {str(e)}"
            print(error_msg)  # Debug output
            return error_msg

def create_interface():
    insta_llm = InstaLLM()
    
    with gr.Blocks(
        title="InstaLLM by HANYA.inc",
        theme=gr.themes.Soft(primary_hue="blue"),
        css=custom_css
    ) as interface:
        with gr.Row():
            with gr.Column(scale=1, elem_classes="title-container"):
                gr.Markdown("""
                # InstaLLM
                ## Powered by HANYA.inc
                
                Your personal AI assistant powered by local LLMs.
                """)
        
        with gr.Row():
            with gr.Column(scale=1):
                model_dropdown = gr.Dropdown(
                    choices=insta_llm._load_available_models(),
                    label="Select Model",
                    interactive=True,
                    value=insta_llm.available_models[0] if insta_llm.available_models else None,
                    allow_custom_value=False
                )
                load_button = gr.Button("Load Model", variant="primary")
                load_status = gr.Textbox(
                    label="Load Status",
                    interactive=False,
                    show_label=True
                )
            
            with gr.Column(scale=2):
                chat_input = gr.Textbox(
                    label="Your Message",
                    placeholder="Type your message here...",
                    lines=3
                )
                generate_button = gr.Button("Generate Response", variant="primary")
                response_output = gr.Textbox(
                    label="Model Response",
                    lines=10,
                    interactive=False
                )
        
        gr.Markdown("""
        ---
        *InstaLLM is a product of HANYA.inc - Bringing AI to your fingertips*
        """)
        
        def update_model_list():
            choices = insta_llm._load_available_models()
            return {"choices": choices, "value": choices[0] if choices else None}
        
        def load_selected_model(model_name):
            return insta_llm.load_model(model_name)
        
        def generate_response(model_name, prompt):
            return insta_llm.generate_response(model_name, prompt)
        
        load_button.click(
            fn=load_selected_model,
            inputs=[model_dropdown],
            outputs=[load_status]
        )
        
        generate_button.click(
            fn=generate_response,
            inputs=[model_dropdown, chat_input],
            outputs=[response_output]
        )
        
        # Auto-refresh model list
        interface.load(update_model_list, None, [model_dropdown])
    
    return interface

if __name__ == "__main__":
    interface = create_interface()
    interface.launch(
        share=True,
        server_name="0.0.0.0",
        server_port=7860,
        show_error=True
    ) 