#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_ADDR 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// BLE Configuration
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
bool newDataReceived = false;

// Circular Queue Configuration
#define QUEUE_SIZE 10
#define MAX_TEXT_LEN 256

struct CircularQueue {
  String buffer[QUEUE_SIZE];
  int front = 0;
  int rear = -1;
  int count = 0;
};

CircularQueue textQueue;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      display.clearDisplay();
      display.setCursor(0,0);
      display.print("Connected!");
      display.display();
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      pServer->startAdvertising();
      display.clearDisplay();
      display.setCursor(0,0);
      display.print("Disconnected!");
      display.display();
    }
};

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String receivedText = pCharacteristic->getValue().c_str();

    if (receivedText.length() > 0) {
      if (textQueue.count < QUEUE_SIZE) {
        textQueue.rear = (textQueue.rear + 1) % QUEUE_SIZE;
        textQueue.buffer[textQueue.rear] = receivedText;
        textQueue.count++;
      } else {
        textQueue.front = (textQueue.front + 1) % QUEUE_SIZE;
        textQueue.rear = (textQueue.rear + 1) % QUEUE_SIZE;
        textQueue.buffer[textQueue.rear] = receivedText;
      }
      newDataReceived = true;
    }
  }
};

void setup() {
  Serial.begin(115200);

  if(!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setTextWrap(true);
  display.print("Initializing BLE...");
  display.display();

  BLEDevice::init("ESP32 Display");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_WRITE
                    );

  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  display.clearDisplay();
  display.print("\nWaiting for connection...");
  display.display();
}

void loop() {
  if (newDataReceived) {
    display.clearDisplay();
    display.setCursor(0, 0);

    if (textQueue.count == 0) {
      display.print("....");
    } else {
      String combinedText = "";
      int currentIndex = textQueue.front;
      for (int i = 0; i < textQueue.count; i++) {
        combinedText += textQueue.buffer[currentIndex];
        combinedText += " ";
        currentIndex = (currentIndex + 1) % QUEUE_SIZE;
      }
      combinedText.trim(); // Remove trailing space
      display.print(combinedText);
    }
    
    display.display();
    newDataReceived = false;
  }
}
