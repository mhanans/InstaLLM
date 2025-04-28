import os
import gradio as gr
from llama_cpp import Llama
from typing import List, Dict

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

.gradio-header {
    background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)) !important;
    padding: 2rem !important;
    border-radius: 10px !important;
    margin-bottom: 2rem !important;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1) !important;
}

/* Add specific styling for markdown content */
.gradio-markdown h1 {
    color: white !important;
    font-size: 2.5rem !important;
    margin: 0 !important;
    text-align: center !important;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3) !important;
}

.gradio-markdown h2 {
    color: rgba(255, 255, 255, 0.9) !important;
    text-align: center !important;
    margin: 0.5rem 0 0 0 !important;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.2) !important;
}

.gradio-markdown p {
    color: rgba(255, 255, 255, 0.9) !important;
    text-align: center !important;
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
        
        # Create models directory if it doesn't exist
        if not os.path.exists(models_dir):
            os.makedirs(models_dir)
        
        # Load available models
        self._load_available_models()
    
    def _load_available_models(self):
        """Load all .gguf files from the models directory"""
        self.available_models = []
        for file in os.listdir(self.models_dir):
            if file.endswith(".gguf"):
                self.available_models.append(file)
        print(f"Found models: {self.available_models}")  # Debug print
    
    def load_model(self, model_name: str) -> str:
        """Load a specific model into memory"""
        if not model_name:
            return "Please select a model first!"
            
        if model_name not in self.available_models:
            return f"Model {model_name} not found!"
        
        if model_name not in self.models:
            try:
                model_path = os.path.join(self.models_dir, model_name)
                self.models[model_name] = Llama(model_path=model_path)
                return f"Model {model_name} loaded successfully!"
            except Exception as e:
                return f"Error loading model: {str(e)}"
        return f"Model {model_name} is already loaded!"
    
    def generate_response(self, model_name: str, prompt: str) -> str:
        """Generate response from the selected model"""
        if not model_name:
            return "Please select a model first!"
            
        if model_name not in self.models:
            return "Please load the model first!"
        
        try:
            response = self.models[model_name](prompt, max_tokens=2000)
            return response['choices'][0]['text']
        except Exception as e:
            return f"Error generating response: {str(e)}"

def create_interface():
    insta_llm = InstaLLM()
    
    with gr.Blocks(
        title="InstaLLM by HANYA.inc",
        theme=gr.themes.Soft(primary_hue="blue"),
        css=custom_css
    ) as interface:
        with gr.Row():
            with gr.Column(scale=1):
                gr.Markdown("""
                # InstaLLM
                ## Powered by HANYA.inc
                
                Your personal AI assistant powered by local LLMs.
                """)
        
        with gr.Row():
            with gr.Column(scale=1):
                model_dropdown = gr.Dropdown(
                    choices=insta_llm.available_models,
                    label="Select Model",
                    interactive=True,
                    value=insta_llm.available_models[0] if insta_llm.available_models else None
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
            insta_llm._load_available_models()
            return {"choices": insta_llm.available_models, "value": insta_llm.available_models[0] if insta_llm.available_models else None}
        
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