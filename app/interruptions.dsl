library

context {
  interrupted: boolean = false;
  lastInterruptionTime: number = 0;
  abruptInterruptionDelay: number = 3000; // Threshold for the duration of the user's phrase, used in smart interruptions. For more information, see the checkSmartInterruption comment. The current delay is set to 3 seconds.
  defInterruptedVADPauseLength: number = 3; // This is a multiplier for the default VADPauseLength. It is used when Dasha is interrupted. 
}

function checkSmartInterruption(): boolean {
// Used when a person starts speaking but is interrupted due to delays, causing them to stop mid-sentence. 
//In such cases, the response is, "Sorry, please continue."
// Modification is not recommended.

// This code checks whether Dasha should stop and listen to the user or continue speaking.
// If the user's phrase takes less time than the abruptInterruptionDelay, it will be considered an abrupt interruption, and Dasha will continue speaking.
// If the user's phrase takes more time than the abruptInterruptionDelay, Dasha will stop and wait for the user to continue.

  if($this.interrupted && (#getCurrentTime() - $this.lastInterruptionTime < $this.abruptInterruptionDelay)) {
    set $this.interrupted = false;

    var gptOptions = $this.openAiApiKey is not null ? {
      model: "openai/gpt-3.5-turbo",
      openai_apikey: $this.openAiApiKey,
      function_call: "none",
      history_length: 0
    } : {
      model: "openai/gpt-35-turbo",
      function_call: "none",
      history_length: 0
    };

    var short = #askGPT(`Instructions: Analyze if the following sentence is complete from a logic perspective and reply strictly with 'yes' or 'no'. Sentence: ` + #getMessageText(), 
      gptOptions: gptOptions);

    #log("askGPT smart interruption: " + short.responseText);

    if(short.responseText.toLowerCase() == "no") {
      #say("sorry_go_ahead");
      return true;
    }
  }

  return false;
}

function handleInterruption(isInterrupted: boolean): unknown {
// This code is responsible for logging cases of interruptions that occur during the dialogue.
// It also dynamically increases the VADPauseLength to ensure that in the next turn of the conversation, Dasha listens to the user until they stop talking.
// We don't recommend to modify it.

  if (isInterrupted) {
    #log("Interrupted");
    set $this.interrupted = true;
    set $this.lastInterruptionTime = #getCurrentTime();

    // If an interruption occurs, increases the VAD pause length used to determine when the user has stopped talking.
    #log("Increase VAD pause length to " + $this.defInterruptedVADPauseLength.toString());
    #setVadPauseLength($this.defInterruptedVADPauseLength);

    #trackEvent("Interrupted");
  }
  else {
    #log("NOT Interrupted. Restore default VAD pause length of " + $this.defVADPauseLength.toString());
    #setVadPauseLength($this.defVADPauseLength);
  }

  return null;  
}