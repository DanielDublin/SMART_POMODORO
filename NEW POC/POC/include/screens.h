#ifndef SCREENS_H
#define SCREENS_H

#include "displays.h"
#include "inputs.h"
#include "neopixel_control.h"
#include "firebase_handler.h"
#include "audio_handler.h"
#include "png_handler.h"
#include <vector>

class Screens {
public:
    typedef enum ScreenChoice {
        CHOOSE_MODE_SCREEN,
        OFFLINE_POMODORO_SETTINGS_SCREEN,
        ONLINE_SESSION_PLANER_SCREEN,
        POMODORO_TIMER_SCREEN,
        WIFI_CONNECTION_SCREEN,
        QR_SCREEN,
        USER_PLANS_SCREEN,
        SESSION_SUMMARY_SCREEN,
        SYNC_TIME_SCREEN,
    } ScreenChoice;

    typedef enum Options {
        ONLINE,
        OFFLINE,
    } Options;

    typedef enum CurrentTimer {
        SHORT_BREAK,
        LONG_BREAK,
        STUDY,
    } CurrentTimer;
    Screens(Audio& audio);
    void init();
    void displayCurrentScreen(bool update);
    void chooseModeScreen(bool update);
    void qrScreen(bool update);
    void wifiNotConnectedScreen(bool update);
    void offlinePomodoroSettingsScreen(bool update);
    void onlineSessionPlannerScreen(bool update);
    void userPlansScreen(bool update);
    void pomodoroTimerScreen(bool update);
    void sessionSummaryScreen(bool update);
    bool updateselectedInputIndex(int value);
    void adjustSelectedValue(int delta);
    int getChoice();
    ScreenChoice getCurrentScreen();
    void switchScreen(ScreenChoice nextScreen);
    void updateMascotDialogueContinuous();
    void resetMascotTextPosition();
    void timeNotSyncedScreen(bool update);
private:
    Audio& audio;
    void handleValuesChange(int* value);
    ScreenChoice currentScreen;
    int selectedInputIndex;
    int currentTotalOptions;
    bool roterySlower;
    int initValues[5] = {25, 5, 15, 4, 2}; // pomodoroLength, shortBreakLength, longBreakLength, longBreakAfter, NumberOfPomodoros
    int valuesSize = 4;
    FirebaseJson userData;
    unsigned long pomodoroStartTime;
    int currentPomodoroMinutes;
    bool isPomodoroRunning;
    bool isPomodoroTimerPaused;
    unsigned long pausedElapsedTime;
    int pomodoroCount;
    String lastTimerStr;
    String sessionName;
    String sessionId;
    unsigned long lastFaceUpdate;
    FaceType currentFace;
    char startTime[30];
    unsigned long lastPollTime = 0;
    static std::vector<std::pair<String, String>> extractSessionNameIdPairs(const String& jsonString);
    static std::vector<String> extractNamesFromPairs(const std::vector<std::pair<String, String>>& pairs);

    // Mascot Dialogue Variables
    unsigned long lastMascotCharTime = 0;
    int mascotDialogueIndex = 0;
    bool mascotDialogueComplete = false;
    String currentMascotText = "";

    // Mascot Dialogue Functions
    void startMascotDialogue(const String& text);
    void updateMascotDialogue();

};

#endif