library
// Sets labels that GPT can apply to conversations after analysis.
// These labels help in collecting and analyzing statistics from various conversations.
// You are encouraged to add any additional labels that may be relevant.
// The name of a label will be output after the conversation ends. The description helps GPT to accurately assign a label to the conversation.
context {
  input label_descriptions: {name: string; description: string;}[] = [
        { name: "CallBack", description: "when the conversation ends with assistant saying they will call the user back later." },
        { name: "Dropoff", description: "when the user hangs up abruptly." },
        { name: "Escalation", description: "when assistant escalated or transferred the call to a human agent." }
  ];
  output labels:string[] = [];
  convlog: {role: string; message: string;}[] = []; 
}


function generateAnalyzerPrompt(l: string, log: string): string {
// This is the main function of the conversation analyzer. 
// It provides logs of the conversation to GPT and returns one of the predefined labels.

  return `Instructions: Analyze the following conversation between user and assistant and label it with strictly one of the following possible labels:
        `
        + l + 
        `None: use this label in case of there are no appropriate labels.

        ---conversation log start---
        ` 
        + log +
        `
        ---conversation log end---

        Reply with just the label name.
        `;
}

function onExit(): boolean {
// This is a global function used to log a conversation and assign a label at the end of the dialogue.
// Modification of this function is not recommended.

  if(!$this.isLabellingEnabled) return false;
  
  #log("onExit()");

  var log: string = "";
  for(var entry in $this.convlog)
    set log = log + "\n" + entry.role + ": " + entry.message;

  var l: string = "";
  for(var entry in $this.label_descriptions)
    set l = l + "\n" + entry.name + ": " + entry.description;


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

  var res = #askGPT($this.generateAnalyzerPrompt(l, log)
        , gptOptions: gptOptions);

  $this.labels.push(res.responseText);

  return true;
} 
