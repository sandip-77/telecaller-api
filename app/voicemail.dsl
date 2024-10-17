library

context {
    vmBuffer: string = "";
}

function generateVmPrompt(buf: string): string
{
// This is a prompt for GPT to determine if the user is a robot based on their responses. Depending on this function's return, the dialogue will either return to the main branch or end the call.
// Modifying this part is not recommended as it might lead to incorrect voicemail recognition.

  return `Analyze and Tell me if the following text is a voicemail or answering machine message, a live person or your are unsure: '` 
          + buf + `'. If it's an empty text, it means "unsure". Reply with strictly "vm", "person" or "unsure" respectively.
          Remember that you shouldn't judge it's a live person too early, unless if they ask you to leave a message right away. 
          Sometimes you need to listen a bit more to judge. For example if they start with "Hello.", you must be unsure, because after that 
          "Hello, you're reached John, I cannot answer right now" might follow (i.e. voicemail), or "Hello, this is John speaking" 
          might follow (i.e. live person).
          Examples:
          "Hello." - unsure
          two "hello/hey" in a row  - person
          "Yes." - person
          "This is [name] speaking" - person
          "This is [name]. I can't answer right now" - vm
          "We're glad you called [name]" - vm
          `;
}

node vm {
  do {
      #setVadPauseLength(0.0);

      set $vmBuffer += " " + #getMessageText().trim();
      #log("$vmBuffer: " + $vmBuffer);

      if($vmBuffer.length() > 0) {

        var gptOptions = $openAiApiKey is not null ? {
          model: "openai/gpt-3.5-turbo",
          openai_apikey: $openAiApiKey,
          function_call: "none",
          history_length: 0
        } : {
          model: "openai/gpt-35-turbo",
          function_call: "none",
          history_length: 0
        };

        // This function asks GPT whether Dasha is talking to a voicemail or not, based on a previously given prompt.
        // For more information about the askGPT function, visit: https://docs.dasha.ai/en-us/default/dasha-script-language/built-in-functions#gpt
        var res = #askGPT($.generateVmPrompt($vmBuffer),
          gptOptions: gptOptions);

        #log("askGPT voicemail detection: " + res.responseText);
      
        if(res.responseText.toLowerCase() == "person") {
          goto main_loop;
        }
        else if(res.responseText.toLowerCase() == "vm") {
          exit;
        }
      }

      wait *;
  }
  transitions {
    main_loop: goto main_loop;
    vm: goto vm on true;
  }
  onexit
    {
        main_loop: do {
          #setVadPauseLength($defVADPauseLength);
        }
    }
}
