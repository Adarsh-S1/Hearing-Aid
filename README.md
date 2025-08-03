# Listening Aid Flutter Application

This project is a comprehensive listening aid system designed to help individuals with hearing disabilities. It uses a Flutter application to capture and transcribe speech in real-time, sending the text via Bluetooth to an ESP32 microcontroller, which then displays it on an OLED screen.

## ✨ Features

  * **Real-time End-to-End Transcription**: Captures audio, transcribes it to text, and displays it on external hardware with minimal delay.
  * **Bluetooth LE Connectivity**: Scans for and connects to the ESP32 peripheral.
  * **Speech-to-Text Engine**: Utilizes the device's native speech recognition capabilities for accurate transcription.
  * **Efficient Data Transmission**: A `LeakyBucket` algorithm throttles the data flow to prevent overwhelming the ESP32, ensuring a smooth text display.
  * **Hardware Integration**: Seamlessly interfaces with an ESP32 and a 0.96" OLED screen for a complete hardware-software solution.

-----

## ⚙️ How It Works

1.  **Bluetooth State Check**: The app first ensures Bluetooth is enabled. If not, it prompts the user to turn it on.
2.  **Device Connection**: The Flutter app scans for and connects to the ESP32, which acts as a BLE peripheral.
3.  **Speech Recognition**: The user taps the microphone button in the app to begin. As they speak, the app transcribes the speech into text in real-time.
4.  **Text Transmission**: The transcribed text is immediately sent over Bluetooth to the connected ESP32. The app uses a smart algorithm to only send the *newly* recognized text, and the `LeakyBucket` class ensures the transmission rate is manageable.
5.  **Hardware Display**: The **ESP32 receives the text** and **displays it on the attached 0.96" OLED screen**. This allows a person with a hearing disability to read the conversation as it happens.

-----

## 🚀 Getting Started

### Prerequisites

  * Flutter SDK
  * An IDE (like VS Code or Android Studio)
  * A physical Android or iOS device

### App Installation

Since only the `lib` folder is provided for the Flutter app, you must create a new project first.

1.  **Create a new Flutter project**:
    ```bash
    flutter create listening_aid
    ```
2.  **Navigate into the project directory**:
    ```bash
    cd listening_aid
    ```
3.  **Replace the `lib` folder**: Delete the default `lib` folder inside your new project and replace it with the `lib` folder from this repository.
4.  **Add dependencies**: Open the `pubspec.yaml` file and add the following packages under `dependencies`:
    ```yaml
    flutter_blue_plus: ^1.31.18 # Or the latest version
    speech_to_text: ^6.6.1     # Or the latest version
    drop_down_list: ^0.0.4      # Or the latest version
    ```
5.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
6.  **Run the app**:
    ```bash
    flutter run
    ```

-----

## 📟 Hardware & ESP32 Code

This project requires a few hardware components to function as a complete system. The code for the microcontroller is included in the `code` folder.

### Required Hardware

  * **ESP32** Microcontroller (any model with Bluetooth support)
  * **0.96" I2C OLED Display** (SSD1306)

### ESP32 Setup

The `code` folder contains the C++ code for the ESP32. You will need the Arduino IDE or PlatformIO to flash this code onto your microcontroller.

The ESP32 code is responsible for:

  * Initializing a BLE server that the Flutter app can connect to.
  * Receiving the incoming text data from the app.
  * Formatting and displaying the text on the OLED screen.

-----

