// Imports default features
import "./hello.dsl";
import "./conversation_analyzer.dsl";
import "./prompts.dsl";
import "./voicemail.dsl";
import "./interruptions.dsl";

context {
    isLabellingEnabled: boolean = true;              
    isFastVmDetectionEnabled: boolean = false;        
    isTalkFirstEnabled: boolean = true;              
    defVADPauseLength: number = 0.4;                   

    input endpoint: string = "";
    input name: string = "";
    input llmModel: string = "openai/gpt-35-turbo";
    input openAiApiKey: string = "";
    input openAiModel: string = "openai/gpt-4";

    finished: boolean = false;
    isFirstTurn: boolean = false;
    dialogueTimer: string = "";
    maxDialogueDuration: number = 5*60*1000;

    top_p: number = 0.1;
}

start node root
{    
    do
    {
        #trackEvent("Captured");

        #connectSafe($endpoint, options: { cache_tts_before_connect: "false" });

        #trackEvent("Connected"); 
        #log(#getConnectOptions());

        set $dialogueTimer = #startTimer($maxDialogueDuration);

        if(#getConnectOptions().options.sip_domain is null) {
          digression disable hello;
        }        

        if($isFastVmDetectionEnabled)
          goto vm;
        else if($isTalkFirstEnabled)
          goto main_loop;
        else {                         
          wait *;
        }
    }
    transitions
    {
      vm: goto vm; 
      main_loop: goto main_loop;
      proceed: goto main_loop on true;
    }
}

node main_loop
{
    do
    {
        $convlog.push({role: "user", message: #getMessageText()});

        $.checkSmartInterruption(); 
        
        var gptOptions = $openAiApiKey is not null ? {
            model: $openAiModel,
            openai_apikey: $openAiApiKey,
            top_p: $top_p
        } : {
            model: $llmModel,
            top_p: $top_p
        };

        // Main prompt processing with GPT
        
        var prompt_final = `prospectName: `+$name + $prompt;
        var a = #answerWithGPT(prompt_final, interruptible:true, gptOptions: gptOptions,
          sayOptions: {
            interruptDelay: 1.0,
            fillerTexts: ["um"],
            fillerSpeed: 1.0,
            fillerDelay: 2.0,
            fillerStartDelay: $isFirstTurn ? 10.0 : 1.0
        });

        #log("Answered with gpt");

        $convlog.push({role: "assistant", message: a.saidPhrase});

        if ($finished) { 
            $.onExit();
            #trackEvent("GPT", #getVisitCount("main_loop").toString());
            exit;
        }        

        if (a.functionCalled) {
          #log("Called a chat function, retry");
          goto retry;
        }

        $.handleInterruption(a.interrupted);

        if($isFirstTurn) {
          set $isFirstTurn = false;
        }

        wait *;
    } 
    transitions {
        main_loop: goto main_loop on true;
        retry: goto main_loop;
    }
}

// Digression to handle user hangups gracefully
global digression main_loop_dig
{
    conditions { on true tags: onclosed; }
    do
    {
        $.onExit();
        #trackEvent("GPT", #getVisitCount("main_loop").toString());
        #trackEvent("UserHangup");
        exit;
    }
}

// End the call if the maximum dialogue duration is reached
digression dialogue_duration_time_exceeded
{
    conditions
    {
        on #isTimerExpired($dialogueTimer) tags: ontick;
    }
    do
    {
        set $status = "TimeOut";
        #log("DIALOGUE TIMER EXCEEDED");
        #trackEvent("DialogueTimerExceeded");

        exit;
    }
}
