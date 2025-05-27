#include "screens.h"

Screens::Screens(Audio& audio) : audio(audio), currentScreen(CHOOSE_MODE_SCREEN), selectedInputIndex(0), currentTotalOptions(2),
                                roterySlower(false), pomodoroStartTime(0), currentPomodoroMinutes(0),
                                isPomodoroRunning(false), isPomodoroTimerPaused(false), pausedElapsedTime(0),
                                pomodoroCount(0), lastTimerStr(""),
                                lastFaceUpdate(0), currentFace(FACE_FOCUSED) {}

void Screens::init() {
    clearTFTScreen();
    clearOLEDScreen();
    String prompt = "Welcome to Study Timer";
    displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, true);
    delay(2000);
    clearTFTScreen();
    displayCurrentScreen(true);
}

void Screens::updateselectedInputIndex(int value) {
    if (!roterySlower) {
        if (value > 0) {
            selectedInputIndex++;
            selectedInputIndex = selectedInputIndex % currentTotalOptions;
        }
        else {
            selectedInputIndex--;
            selectedInputIndex = abs(selectedInputIndex) % currentTotalOptions;
        }
        audio.playButton(0.7);
        Serial.printf("selectedInputIndex: %d\n", selectedInputIndex);
        displayCurrentScreen(true);  // Update display immediately after selection change
    }
    else {
        roterySlower = !roterySlower;
    }
}

void Screens::displayCurrentScreen(bool update) {
    if (currentScreen == CHOOSE_MODE_SCREEN) {
        chooseModeScreen(update);
    }
    else if (currentScreen == ONLINE_SESSION_PLANER_SCREEN) {
        onlineSessionPlannerScreen(update);
    }
    else if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN) {
        offlinePomodoroSettingsScreen(update);
    }
    else if (currentScreen == POMODORO_TIMER_SCREEN) {
        pomodoroTimerScreen(update);
    }
}

void Screens::chooseModeScreen(bool update) {
    currentTotalOptions = 2;
    String options[] = {"Online", "Offline"};
    drawMenu(options, currentTotalOptions, selectedInputIndex, 200, update);
    String prompt = "Choose Wi-Fi mode:";
    displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, false);
}

void Screens::handleValuesChange(int* value) {
  if (*value < 0) return;
  int rotaryValue = handleRotaryEncoder();
  if (rotaryValue != 0) {
    int newValue = *value + rotaryValue;
    // Ensure value stays at minimum 1
    if (newValue < 1) {
      newValue = 1;
    }
    *value = newValue;
  }
}

void Screens::offlinePomodoroSettingsScreen(bool update) {
  currentTotalOptions = 6;
  // int pomodoroLen = 30, shortBreakLen = 5, longBreakLen = 30, longBreakAfter = 4;
  String options[] = {"Confirm", "Return"};
  int optionsSize = sizeof(options) / sizeof(options[0]);
  String prompt = "Settings";
  String pomodoroLenStr = "Pomodoro Duration: ";
  String shortBreakLenStr = "Short Break Duration: ";
  String longBreakLenStr = "Long Break Duration: ";
  String longBreakAfterStr = "Long Break After: ";
  displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);
  displayTFTText(pomodoroLenStr, 0, 50, 2, TFT_BLUE, false);
  displayTFTText(shortBreakLenStr, 0, 100, 2, TFT_BLUE, false);
  displayTFTText(longBreakLenStr, 0, 150, 2, TFT_BLUE, false);
  displayTFTText(longBreakAfterStr, 0, 200, 2, TFT_BLUE, false);
  if (selectedInputIndex < valuesSize) {
    handleValuesChange(&initValuesForOffline[selectedInputIndex]);
  }
  drawValues(initValuesForOffline, valuesSize, options, optionsSize, selectedInputIndex, 50, update);
}

void Screens::onlineSessionPlannerScreen(bool update) {
  currentTotalOptions = 2;
  String options[] = {"Confirm", "Return"};
  String rawUserData = userData.raw();
  
  // Always draw the static text, regardless of update flag
  String prompt = "Session Planner";
  String deadlineString = "Deadline: ";
  String sessionPerDayString = "Session per day: ";
  String studyDaysString = "Study days: ";
  displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);
  displayTFTText(deadlineString, 0, 50, 2, TFT_BLUE, false);
  displayTFTText(sessionPerDayString, 0, 100, 2, TFT_BLUE, false);
  displayTFTText(studyDaysString, 0, 150, 2, TFT_BLUE, false);

  if (rawUserData.length() == 0) {
    String data = readFromFirestore("test_collection/session1");  //hard coded for now
    Serial.println(data);
    userData.setJsonData(data);
  }

  FirebaseJsonData data;
  String deadline, sessionPerDay, studyDays;
  if (userData.get(data, "fields/deadline/timestampValue")) {
      deadline = data.stringValue;
  }
  if (userData.get(data, "fields/sessionPerDay/integerValue")) {
      sessionPerDay = data.stringValue;
  }
  if (userData.get(data, "fields/studyDays/stringValue")) {
      studyDays = data.stringValue;
  }
  
  // Format deadline to DD/MM
  String day = deadline.substring(8, 10);
  String month = deadline.substring(5, 7);
  String deadlineFormatted = day + "/" + month;

  displayTFTText(deadlineFormatted, 300, 50, 2, TFT_BLUE, false);
  displayTFTText(sessionPerDay, 300, 100, 2, TFT_BLUE, false);
  displayTFTText(studyDays, 300, 150, 2, TFT_BLUE, false);
  
  drawMenu(options, currentTotalOptions, selectedInputIndex, 250, update);
}

  void Screens::adjustSelectedValue(int delta) {
    if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN && selectedInputIndex < valuesSize) {
        int newValue = initValuesForOffline[selectedInputIndex] + delta;
        if (newValue >= 1) {
            initValuesForOffline[selectedInputIndex] = newValue;
            audio.playButton(0.7);  // Beep for value change
        }
      }
    }


void Screens::pomodoroTimerScreen(bool update) {
  currentTotalOptions = 2;  // Stop and Pause/Resume
  String options[] = {"Stop", isPomodoroTimerPaused ? "Resume" : "Pause"};

  if (!isPomodoroRunning) {
    pomodoroStartTime = millis();
    isPomodoroRunning = true;
    isPomodoroTimerPaused = false;
    pausedElapsedTime = 0;
    currentPomodoroMinutes = initValuesForOffline[0]; // Use the set pomodoro length
    lastTimerStr = "";  // Reset last timer string
    lastFaceUpdate = millis();
    currentFace = FACE_FOCUSED;
    
    // Initial screen setup
    clearTFTScreen();
    clearOLEDScreen();
    String sessionType = "Focus Time";
    displayTFTText(sessionType, centerTextX(sessionType, 3), 50, 3, TFT_BLUE, false);
    drawMenu(options, currentTotalOptions, selectedInputIndex, 250, true);
    displayOLEDFace(currentFace);
  }
  
  // Update face animation
  unsigned long currentTime = millis();
  if (currentTime - lastFaceUpdate >= FACE_UPDATE_INTERVAL) {
    // Switch between the two faces
    currentFace = (currentFace == FACE_FOCUSED) ? FACE_TIRED : FACE_FOCUSED;
    displayOLEDFace(currentFace);
    lastFaceUpdate = currentTime;
  }

  // Calculate remaining time
  unsigned long elapsedSeconds;
  if (isPomodoroTimerPaused) {
    elapsedSeconds = pausedElapsedTime / 1000;
  } else {
    elapsedSeconds = (millis() - pomodoroStartTime) / 1000;
  }
  
  int totalSeconds = (currentPomodoroMinutes * 60) - elapsedSeconds;
  int remainingMinutes = totalSeconds / 60;
  int remainingSeconds = totalSeconds % 60;

  if (totalSeconds <= 0) {
    // Pomodoro session finished
    clearTFTScreen();
    clearOLEDScreen();
    audio.playCharSound(true, 0.4);
    pomodoroCount++;
    lastTimerStr = "";  // Reset last timer string
    
    // Check if it's time for a long break
    if (pomodoroCount % initValuesForOffline[3] == 0) {
      currentPomodoroMinutes = initValuesForOffline[2]; // Long break
      String message = "Long Break Time!";
      displayTFTText(message, centerTextX(message, 3), 50, 3, TFT_GREEN, false);
    } else {
      currentPomodoroMinutes = initValuesForOffline[1]; // Short break
      String message = "Short Break Time!";
      displayTFTText(message, centerTextX(message, 3), 50, 3, TFT_GREEN, false);
    }
    currentFace = FACE_TIRED;  // Use tired/relaxed face for breaks
    displayOLEDFace(currentFace);
    pomodoroStartTime = millis();
    lastFaceUpdate = millis();
    drawMenu(options, currentTotalOptions, selectedInputIndex, 250, true);
    return;
  }

  // Format new timer string
  String newTimerStr = String(remainingMinutes) + ":" + (remainingSeconds < 10 ? "0" : "") + String(remainingSeconds);
  
  // Only update if the time has changed
  if (newTimerStr != lastTimerStr) {
    // Calculate position for centered timer
    int size = 4;
    int timerWidth = getDigitWidth(size) * newTimerStr.length() + getDigitWidth(size)/2; // Add half digit width for colon spacing
    int timerX = (ILI_SCREEN_WIDTH - timerWidth) / 2;
    
    // Update only changed digits
    displayTFTTimer(newTimerStr, lastTimerStr, timerX, 150, size, TFT_WHITE);
    
    lastTimerStr = newTimerStr;
  }

  if (update) {
    // Only redraw menu if update is requested
    drawMenu(options, currentTotalOptions, selectedInputIndex, 250, false);
  }
}

int Screens::getChoice() {
    if (currentScreen == CHOOSE_MODE_SCREEN) {
        if (selectedInputIndex == ONLINE) {
            return ONLINE;
        }
        return OFFLINE;
    }
    else if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN) {
        if (selectedInputIndex < 4) {
            return selectedInputIndex;
        }
        else if (selectedInputIndex == CONFIRM) {
            return CONFIRM;
        }
        return RETURN;
    }
    else if (currentScreen == ONLINE_SESSION_PLANER_SCREEN) {
        if (selectedInputIndex == 0) {  // Confirm
            return CONFIRM;
        }
        else if (selectedInputIndex == 1) {  // Return
            return RETURN;
        }
        return -1;
    }
    else if (currentScreen == POMODORO_TIMER_SCREEN) {
        if (selectedInputIndex == 0) {  // Stop
            isPomodoroRunning = false;  // Stop the timer
            return FIRST_OPTION;  // Return to settings
        }
        else if (selectedInputIndex == 1) {  // Pause/Resume
            if (isPomodoroTimerPaused) {
                // Resume - update start time to account for paused duration
                pomodoroStartTime = millis() - pausedElapsedTime;
                isPomodoroTimerPaused = false;
            } else {
                // Pause - store current elapsed time
                pausedElapsedTime = millis() - pomodoroStartTime;
                isPomodoroTimerPaused = true;
            }
            audio.playButton(0.7);  // Play feedback sound
            displayCurrentScreen(true);  // Force screen update to show new button text
            return -1;  // Stay on current screen
        }
    }
    return -1;
}

Screens::ScreenChoice Screens::getCurrentScreen() {
    return currentScreen;
}

void Screens::switchScreen(Screens::ScreenChoice nextScreen) {
    clearTFTScreen();
    selectedInputIndex = 0;
    currentScreen = nextScreen;
}