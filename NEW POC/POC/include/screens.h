#ifndef SCREENS_H
#define SCREENS_H

#include "displays.h"
#include "inputs.h"
#include "firebase_handler.h"
#include "audio_handler.h"
#include "png_handler.h"


#define FIRST_OPTION 0 //all in one enum or in define????????? fix in loop later
#define SECOND_OPTION 1
#define CONFIRM 4
#define RETURN 5

class Screens {
public:
    typedef enum ScreenChoice {
        CHOOSE_MODE_SCREEN,
        WIFI_CONNECTION_SCREEN,
        QR_SCREEN,
        OFFLINE_POMODORO_SETTINGS_SCREEN,
        ONLINE_SESSION_PLANER_SCREEN,
        POMODORO_TIMER_SCREEN
    } ScreenChoice;

    typedef enum Options {
        ONLINE,
        OFFLINE
    } Options;

    Screens(Audio& audio);  // Constructor now accepts Audio&
    void init();
    void displayCurrentScreen(bool update);
    void chooseModeScreen(bool update);
    void qrScreen(bool update);
    void offlinePomodoroSettingsScreen(bool update);
    void onlineSessionPlannerScreen(bool update);
    void pomodoroTimerScreen(bool update);
    void updateselectedInputIndex(int value);
    void adjustSelectedValue(int delta);  // New method for value adjustments
    int getChoice();  // Changed to return int instead of ScreenChoice
    ScreenChoice getCurrentScreen();
    void switchScreen(ScreenChoice nextScreen);
private:
    Audio& audio;
    void handleValuesChange(int* value);
    ScreenChoice currentScreen;
    int selectedInputIndex;
    int currentTotalOptions;
    bool roterySlower;
    int initValuesForOffline[4] = {30, 5, 30, 4};
    int valuesSize = 4;
    FirebaseJson userData;
    unsigned long pomodoroStartTime;
    int currentPomodoroMinutes;
    bool isPomodoroRunning;
    bool isPomodoroTimerPaused;  // New variable to track pause state
    unsigned long pausedElapsedTime;  // New variable to store elapsed time when paused
    int pomodoroCount;
    String lastTimerStr;  // Track last displayed timer value
    // Face animation variables
    unsigned long lastFaceUpdate;
    FaceType currentFace;
    const unsigned long FACE_UPDATE_INTERVAL = 10000; // Change face every 10 seconds
};
#endif 