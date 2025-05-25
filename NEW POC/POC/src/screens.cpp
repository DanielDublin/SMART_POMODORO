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
}

void Screens::chooseModeScreen(bool update) {
  currentTotalOptions = 2;
  String prompt = "Choose Wi-Fi mode:";
  String options[] = {"Online", "Offline"};
  displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, false);
  drawMenu(options, currentTotalOptions, selectedInputIndex, 200, update);
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
}

Screens::Screen Screens::getCurrentScreen() {
    return currentScreen;
}

void Screens::switchScreen(Screens::Screen nextScreen) {
    clearTFTScreen();
    selectedInputIndex = 0;
    currentScreen = nextScreen;
}