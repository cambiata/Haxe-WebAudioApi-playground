package;

import js.Browser;
import js.html.audio.AudioContext;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Worker;
import js.Lib;

/**
 * ...
 * @author 
 */

class Main 
{
	
	static function main() 
	{
		new Metronome();
	}
	
}

typedef QueueNote = { note:Int, time:Float };

class Metronome {
	
	public function new() { 
		
		this.init();
	};
	
	var audioContext:AudioContext;
	//var audioContext = null;
	var isPlaying = false;      // Are we currently playing?
	var startTime:Float;              // The start time of the entire sequence.
	var current16thNote:Int;        // What note is currently last scheduled?
	var tempo = 120.0;          // tempo (in beats per minute)
	var lookahead = 25.0;       // How frequently to call scheduling function (in milliseconds)
	var scheduleAheadTime = 0.1;    // How far ahead to schedule audio (sec) This is calculated from lookahead, and overlaps with next interval (in case the timer is late)
	var nextNoteTime = 0.0;     // when the next note is due.
	var noteResolution = 0;     // 0 == 16th, 1 == 8th, 2 == quarter note
	var noteLength = 0.1;      // length of "beep" (in seconds)
	var canvas:CanvasElement;// ,                 // the canvas element
	var canvasContext:CanvasRenderingContext2D; // canvasContext is the canvas" context 2D
	var last16thNoteDrawn = -1; // the last "box" we drew on the screen
	var notesInQueue:Array<QueueNote> = [];      // the notes that have been put into the web audio, and may or may not have played yet. {note, time}
	var timerWorker:Worker = null;     // The Web Worker used to fire timer messages

	function nextNote() {
		// Advance current note and time by a 16th note...
		var secondsPerBeat = 60.0 / tempo;    // Notice this picks up the CURRENT tempo value to calculate beat length.
		nextNoteTime += 0.25 * secondsPerBeat;    // Add beat length to last beat time
		current16thNote++;    // Advance the beat number, wrap to zero
		if (current16thNote >= 16) current16thNote = 0;
	}

	function scheduleNote( beatNumber:Int, time:Float ) {
	    // push the note on the queue, even if we"re not playing.
		notesInQueue.push( { note: beatNumber, time: time } );

		if ( (noteResolution==1) && (beatNumber%2 != 0)) return; // we"re not playing non-8th 16th notes
		if ( (noteResolution==2) && (beatNumber%4 != 0)) return; // we"re not playing non-quarter 8th notes

		// create an oscillator
		var osc = audioContext.createOscillator();
		osc.connect( audioContext.destination, 0, 0 );
		if (beatNumber % 16 == 0)    // beat 0 == low pitch
			osc.frequency.value = 880.0;
		else if (beatNumber % 4 == 0 )    // quarter notes = medium pitch
			osc.frequency.value = 440.0;
		else                        // other 16th notes = high pitch
		osc.frequency.value = 220.0;

		osc.start( time );
		osc.stop( time + noteLength );
	}


	function scheduler() {

	    // while there are notes that will need to play before the next interval, 
	    // schedule them and advance the pointer.
	    while (nextNoteTime < audioContext.currentTime + scheduleAheadTime ) {
		  scheduleNote( current16thNote, nextNoteTime );
		  nextNote();
	    }

	}

	function play() {
		isPlaying = !isPlaying;

		if (isPlaying) { // start playing
			current16thNote = 0;
			nextNoteTime = audioContext.currentTime;
			timerWorker.postMessage("start");
			return "stop";
		} else {
			timerWorker.postMessage("stop");
			return "play";
		}
	}

	function resetCanvas (e) {
	    // resize the canvas - but remember - this clears the canvas too.
	    canvas.width = Browser.window.innerWidth;
	    canvas.height = Browser.window.innerHeight;
	    //make sure we scroll to the top left.
	    Browser.window.scrollTo(0,0); 
	}


	function draw(float:Float) {
		var currentNote = last16thNoteDrawn;
		var currentTime = audioContext.currentTime;

		while ((notesInQueue.length > 0) && (notesInQueue[0].time < currentTime)) {
			currentNote = notesInQueue[0].note;
			notesInQueue.splice(0,1);   // remove note from queue
		}

		// We only need to draw if the note has moved.
		if (last16thNoteDrawn != currentNote) {
			var x = Math.floor( canvas.width / 18 );
			canvasContext.clearRect(0,0,canvas.width, canvas.height); 
			for (i in 0...16) {
				canvasContext.fillStyle = ( currentNote == i ) ? 
				((currentNote%4 == 0)?"red":"blue") : "black";
				canvasContext.fillRect( x * (i+1), x, x/2, x/2 );
			}
			last16thNoteDrawn = currentNote;
		}

		this.requestAnimFrame(draw);
		return true;
	}

	var requestAnimFrame:(Float->Bool)->Int;

	function init(){

		Browser.document.getElementById("play").onmousedown = function(e) {
			play();
		}

		Browser.document.getElementById('tempo').oninput = function(event) {
			this.tempo = event.target.value; 
			Browser.document.getElementById('showTempo').innerHTML = Std.string(tempo);
		}
		
		Browser.document.getElementById('selResolution').onchange = function(event) {
			this.noteResolution = event.target.selectedIndex;		
		}

		var container = Browser.document.createDivElement();

		container.className = "container";
		canvas = Browser.document.createCanvasElement();
		canvasContext = canvas.getContext( "2d" );
		canvas.width = Browser.window.innerWidth; 
		canvas.height = Browser.window.innerHeight; 
		Browser.document.body.appendChild( container );
		container.appendChild(canvas);    
		canvasContext.strokeStyle = "#ffffff";
		canvasContext.lineWidth = 2;

		this.audioContext = new AudioContext();

		// if we wanted to load audio files, etc., this is where we should do it.

		//Browser.window.onorientationchange = resetCanvas;
		Browser.window.onresize = resetCanvas;

		this.requestAnimFrame = Browser.window.requestAnimationFrame;
		this.requestAnimFrame(this.draw);  
		
		timerWorker = new Worker("js/metronomeworker.js");
		timerWorker.onmessage = function(e) {
			if (e.data == "tick") 
				scheduler()
			else
				trace("message: " + e.data);
		};
		timerWorker.postMessage({"interval":lookahead});
	}
	
}