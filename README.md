# HANYA: InstaLLM

A simple Gradio interface for chatting with local GGUF models.

## Setup

1. Install the required dependencies:
```bash
pip install -r requirements.txt
```

2. Create a `models` directory in the same folder as `app.py`

3. Place your GGUF model files in the `models` directory

## Usage

1. Run the application:
```bash
python app.py
```

2. The application will open in your web browser with the following features:
   - A dropdown menu to select available GGUF models
   - A "Load Model" button to load the selected model into memory
   - A text input area for your messages
   - A "Generate Response" button to get responses from the model

## Features

- Automatically detects GGUF models in the models directory
- Supports multiple models
- Simple and intuitive interface
- Real-time model loading and response generation

## Notes

- Make sure your GGUF models are compatible with llama-cpp-python
- The application will create the models directory if it doesn't exist
- Models are loaded into memory when selected and remain loaded until the application is restarted 