#include "screens.h"

Screens::Screens() : currentScreen(CHOOSE_MODE_SCREEN), selectedInputIndex(0), currentTotalOptions(2), roterySlower(false) {}

void Screens::updateselectedInputIndex(int value) {
    if (!roterySlower){
  if (value > 0) {
    selectedInputIndex++;
    selectedInputIndex = selectedInputIndex % currentTotalOptions;
  }
  else {
    selectedInputIndex--;
    selectedInputIndex = abs(selectedInputIndex) % currentTotalOptions;
  }
  Serial.printf("selectedInputIndex: %d\n", selectedInputIndex);
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
}

void Screens::chooseModeScreen(bool update) {
  currentTotalOptions = 2;
  String prompt = "Choose Wi-Fi mode:";
  String options[] = {"Online", "Offline"};
  displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, false);
  drawMenu(options, currentTotalOptions, selectedInputIndex, 200, update);
}

void Screens::handleValuesChange(int* value) {
  if (*value < 0) return;
  int rotaryValue = handleRotaryEncoder();
  if (rotaryValue != 0) {
    // if (*value + rotaryValue == 10 || *value + rotaryValue == 9) {
    //   *value = (*value + rotaryValue) < 0 ? 0 : *value + rotaryValue;
    //   clearTFTScreen();
    // }
    // else {
      *value = (*value + rotaryValue) < 0 ? 0 : *value + rotaryValue;
    // }
  }
}

void Screens::offlinePomodoroSettingsScreen(bool update) {
  currentTotalOptions = 6;
  // int pomodoroLen = 30, shortBreakLen = 5, longBreakLen = 30, longBreakAfter = 4;
  String options[] = {"Confirm", "Return"};
  int optionsSize = sizeof(options) / sizeof(options[0]);
  String prompt = "Settings";
  String pomodoroLenStr = "Pomodoro Length: ";
  String shortBreakLenStr = "Short Break Length: ";
  String longBreakLenStr = "Long Break Length: ";
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
  if (rawUserData.length() == 0) {
    String data = readFromFirestore("test_collection/session1");  //hard coded for now
    Serial.println(data);
    userData.setJsonData(data);
  }
  else {
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
    String prompt = "Session Planner";
    String deadlineString = "Deadline: ";
    String sessionPerDayString = "Session per day: ";
    String studyDaysString = "Study days: ";
    displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);

    displayTFTText(deadlineString, 0, 50, 2, TFT_BLUE, false);
    displayTFTText(deadlineFormatted, 300, 50, 2, TFT_BLUE, false);

    displayTFTText(sessionPerDayString, 0, 100, 2, TFT_BLUE, false);
    displayTFTText(sessionPerDay, 300, 100, 2, TFT_BLUE, false);

    displayTFTText(studyDaysString, 0, 150, 2, TFT_BLUE, false);
    displayTFTText(studyDays, 300, 150, 2, TFT_BLUE, false);
  }
  drawMenu(options, currentTotalOptions, selectedInputIndex, 250, update);
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

    }
}

Screens::Screen Screens::getCurrentScreen() {
    return currentScreen;
}

void Screens::switchScreen(Screens::Screen nextScreen) {
    clearTFTScreen();
    selectedInputIndex = 0;
    currentScreen = nextScreen;
}