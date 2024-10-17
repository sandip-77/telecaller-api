library

context {
  output status:string? = null;
  output serviceStatus:string? = null;
}

// These are the settings for pings (e.g., "Hello?", "Are you there?") when there is no response from the user.
// The types of these settings are defined here and it is not recommended to change them.
// You can find their descriptions and set values in the 'configuration' variable below.
type HelloConfiguration = {
    idleTimeLimit:number;
    lastIdleTime: number;
    retriesLimit: number;
    counter: number;
} with {
    preprocessorExecution(): boolean {
        set $this.lastIdleTime = 0;
        set $this.counter = 0;
        return false;
    }
}
;

// Reaction if nothing meaningful occurs in the dialogue for an long period.
preprocessor digression hello
{
    conditions
    {
        on #getIdleTime() - digression.hello.configuration.lastIdleTime > digression.hello.configuration.idleTimeLimit tags: ontick;
    }
    var configuration: HelloConfiguration = {
        idleTimeLimit: 5000,            // Maximum amount of silence time before a ping is sent. The higher the number, the longer Dasha will wait before pinging the user. Currently set to 5 seconds.
        lastIdleTime: 0,                // Checks the time since the last ping and determines when to send the next ping if the user hasn't responded to previous ones.
        retriesLimit: 1,                // Number of times Dasha will ping the user before ending the call.
        counter: 0                      // Number of pings sent during the current silence period.
    };
    do
    {
        set digression.hello.configuration.lastIdleTime=#getIdleTime();
        if (digression.hello.configuration.counter >= digression.hello.configuration.retriesLimit)
        {
            set $status = "EmptyCall";
            set $serviceStatus = "Done";
            exit;
        }
        set digression.hello.configuration.counter=digression.hello.configuration.counter+1;
        #say("hello",options:{ skipIntermediate:true }, repeatMode: "ignore");
        return;
    }
}
// This section resets the ping counter if the user responds.
//This prevents Dasha from ending the conversation if there are two or more pings separated by the user's responses.
preprocessor digression hello_preprocessor
{
    conditions
    {
        on digression.hello.configuration.preprocessorExecution() priority 50000 tags: ontext;
    }
    do
    {
        // never be there because preprocessorExecution must return always false
        set digression.hello.configuration.lastIdleTime = 0;
        set digression.hello.configuration.counter = 0;
        return;
    }
}
