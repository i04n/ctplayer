/*    
 *    Copyright (c) 2009 Open Video Ads - Option 3 Ventures Limited
 *
 *    This file is part of the Open Video Ads VAST framework.
 *
 *    The VAST framework is free software: you can redistribute it 
 *    and/or modify it under the terms of the Lesser GNU General Public License 
 *    as published by the Free Software Foundation, either version 3 of 
 *    the License, or (at your option) any later version.
 *
 *    The VAST framework is distributed in the hope that it will be 
 *    useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the Lesser GNU General Public License
 *    along with the framework.  If not, see <http://www.gnu.org/licenses/>.
 */
package org.openvideoads.vast.schedule {
	import org.openvideoads.base.Debuggable;
	import org.openvideoads.util.Timestamp;
	import org.openvideoads.vast.VASTController;
	import org.openvideoads.vast.schedule.ads.AdSchedule;
	import org.openvideoads.vast.schedule.ads.AdSlot;
	import org.openvideoads.vast.tracking.TimeEvent;

	/**
	 * @author Paul Schulz
	 */
	public class StreamSequence extends Debuggable {
		protected var _vastController:VASTController = null;
		protected var _sequence:Array = new Array();
		protected var _totalDuration:int = 0;
		protected var _lastPauseTime:int = 0;
		protected var _bitrate:String = null;
		protected var _baseURL:String = null;
		protected var _timerFactor:int = 1;
		protected var _lastTrackedStreamIndex:int = -1;
		
		public function StreamSequence(vastController:VASTController=null, streams:Array=null, adSequence:AdSchedule=null, bitrate:String=null, baseURL:String=null, timerFactor:int=1, previewImage:String=null):void {
			if(streams != null) {
				initialise(vastController, streams, adSequence, bitrate, baseURL, timerFactor);
			}
			else _vastController = vastController;
		}

		public function initialise(vastController:VASTController, streams:Array=null, adSequence:AdSchedule=null, bitrate:String=null, baseURL:String=null, timerFactor:int=1, previewImage:String=null):void {
			_vastController = vastController;
			_timerFactor = timerFactor;
						
			if(bitrate != null) {
				_bitrate = bitrate;
			}
			if(baseURL != null) {
				_baseURL = baseURL;
			}
			if(streams != null && adSequence != null) {
				_totalDuration = build(streams, adSequence, previewImage);			
			}
		}

		public function get vastController():VASTController {
			return _vastController;
		}
		
		public function get length():int {
			return _sequence.length;
		}
		
		public function streamAt(index:int):Stream {
			return _sequence[index];
		}
		
		public function get totalDuration():int {
			return _totalDuration;
		}
		
		public function hasBitRate():Boolean {
			return _bitrate != null;
		}
		
		public function get bitrate():String {
			return _bitrate;
		}
		
		public function hasBaseURL():Boolean {
			return _baseURL != null;
		}
		
		public function get baseURL():String {
			return _baseURL;
		}

		public function markPaused(timeInSeconds:int):void {
			_lastPauseTime = timeInSeconds;
		}
		
		public function get lastPauseTime():int {
			return _lastPauseTime;
		}
		
		public function resetPauseMarker():void {
			_lastPauseTime = -1;
		}
		
		public function getStartingStreamIndex():int {
			for(var i:int=0; i < _sequence.length; i++) {
				if(_sequence[i].isStream()) return i;
			}	
			return 0;
		}
		
		public function getStreamSequenceIndexGivenOriginatingIndex(originalIndex:int, excludeSlices:Boolean=false, excludeMidRolls:Boolean=false):int {
			var excludeCounter:int = 0;
			for(var i:int=0; i < _sequence.length; i++) {
				if(!(_sequence[i] is AdSlot)) {
					if(_sequence[i].originatingStreamIndex == originalIndex) {
						return i-excludeCounter;
					}
					else if(_sequence[i].isSlice() && excludeSlices) ++excludeCounter;
				}
				else if(_sequence[i].isMidRoll() && excludeMidRolls) ++excludeCounter;
			}	
			return -1;
		}		
		
		private function createNewMetricsTracker():Object {
			var currentMetrics:Object = new Object();
			currentMetrics.usedAdDuration = 0;		
			currentMetrics.remainingActiveShowDuration = 0;	
			currentMetrics.usedActiveShowDuration = 0;
			currentMetrics.totalActiveShowDuration = 0;
			currentMetrics.associatedStreamIndex = 0;	
			currentMetrics.atStart = false;		
			return currentMetrics;
		}

		public function addStream(stream:Stream, declareTrackingPoints:Boolean=true):void {
			if(declareTrackingPoints) stream.declareTrackingPoints(0);
			_sequence.push(stream);
			_vastController.onScheduleStream(_sequence.length-1, stream);
		}
		
		public function addRemainingStreamSlice(streams:Array, streamMetrics:Object, label:String, totalDuration:int):int {
			addStream(new Stream(this,
			                     _vastController,
			                     _sequence.length,
			                     label + streamMetrics.associatedStreamIndex + "-" + _sequence.length,
			                     streams[streamMetrics.associatedStreamIndex].id, //filename,
							     Timestamp.secondsToTimestamp(streamMetrics.usedActiveShowDuration),
							     new String(streamMetrics.remainingActiveShowDuration),
							     new String(streamMetrics.totalActiveShowDuration),
							     true,
							     _baseURL,
							     "any", //mp4
							     "any", //"streaming",
							     "any",
								 streams[streamMetrics.associatedStreamIndex].playOnce,
								 streams[streamMetrics.associatedStreamIndex].metaData,
						 		 streams[streamMetrics.associatedStreamIndex].autoPlay,
								 streams[streamMetrics.associatedStreamIndex].provider,
								 streams[streamMetrics.associatedStreamIndex].player,
						 		 null,
								 streamMetrics.associatedStreamIndex,
								 true)); 
			streamMetrics.usedActiveShowDuration += streamMetrics.remainingActiveShowDuration;
			var newDuration:int = totalDuration + streamMetrics.remainingActiveShowDuration;
			doLog("Total play duration is now " + newDuration, Debuggable.DEBUG_SEGMENT_FORMATION);			
			return newDuration;
		}

		public function build(streams:Array, adSequence:AdSchedule, previewImage:String=null):int {
			doLogAndTrace("*** BUILDING THE STREAM SEQUENCE FROM " + streams.length + " SHOW STREAMS AND " + adSequence.length + " AD SLOTS", adSequence, Debuggable.DEBUG_SEGMENT_FORMATION);
			var adSlots:Array = adSequence.adSlots;
			var trackingInfo:Array = new Array();
			var totalDuration:int = 0;
			
			var currentMetrics:Object = createNewMetricsTracker();
			var previousMetrics:Object = createNewMetricsTracker();
//			currentMetrics.associatedStreamIndex = 0;
//			var previousMetrics:Object = currentMetrics;
			
			if(adSequence.hasLinearAds()) {
				for(var i:int = 0; i < adSlots.length; i++) {
					if(previousMetrics.associatedStreamIndex != adSlots[i].associatedStreamIndex) {	
						previousMetrics = currentMetrics;
						currentMetrics = createNewMetricsTracker();
						currentMetrics.associatedStreamIndex = adSlots[i].associatedStreamIndex;
					}
					if(streams.length > 0) {
						currentMetrics.totalActiveShowDuration = Timestamp.timestampToSeconds(streams[adSlots[i].associatedStreamIndex].duration);						
					}
					if(!adSlots[i].isLinear() && adSlots[i].isActive()) {
						// deal with it as an overlay that goes over the current stream
//						adSlots[i].originatingAssociatedStreamIndex = adSlots[i].associatedStreamIndex;
						adSlots[i].associatedStreamIndex = _sequence.length;
					}
					else if(adSlots[i].isLinear() && adSlots[i].isActive()) {
						if(adSlots[i].isPreRoll()) {
							if(!adSlots[i].isCopy()) {						
								doLog("Slotting in a pre-roll ad with id: " + adSlots[i].id, Debuggable.DEBUG_SEGMENT_FORMATION);
								if(currentMetrics.associatedStreamIndex != previousMetrics.associatedStreamIndex) {
									if((previousMetrics.usedActiveShowDuration > 0) && previousMetrics.usedActiveShowDuration < previousMetrics.totalActiveShowDuration) {
										// we still have some of the previous show stream to schedule before we do a pre-roll ad for the next stream
										previousMetrics.remainingActiveShowDuration = previousMetrics.totalActiveShowDuration - previousMetrics.usedActiveShowDuration;
										doLog("Slotting in the remaining (previous) show segment to play before pre-roll - segment duration is " + previousMetrics.remainingActiveShowDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
										totalDuration += addRemainingStreamSlice(streams, previousMetrics, "show-a-", totalDuration);
										previousMetrics.associatedStreamIndex = previousMetrics.associatedStreamIndex + 1;
									}
	                                
									// Add in any streams that we have to play before this ad slot has to be played
									for(var m:int=previousMetrics.associatedStreamIndex; m < adSlots[i].associatedStreamIndex && m < streams.length; m++) {
										doLog("Sequencing stream " + streams[m].filename + " without advertising", Debuggable.DEBUG_SEGMENT_FORMATION);
										addStream(new Stream(this, 
										                     _vastController, 
										                     m, 
										                     "show-b-" + m + "-" + _sequence.length, 
										                     streams[m].id, //filename, 
										                     "00:00:00", 
										                     Timestamp.timestampToSecondsString(streams[m].duration), 
										                     Timestamp.timestampToSecondsString(streams[m].duration), 
										                     streams[m].reduceLength, 
										                     _baseURL,
														     "any", //mp4
														     "any", //"streaming",
														     "any",
										                     streams[m].playOnce,					
													 		 streams[m].metaData,
													 		 streams[m].autoPlay,
													 		 streams[m].provider,
													 		 streams[m].player,
													 		 null,
													 		 m)); 
										totalDuration += Timestamp.timestampToSeconds(streams[m].duration);
										previousMetrics.associatedStreamIndex = m;
										doLog("Total play duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
									}		
								}
							}
						}
						else if(adSlots[i].isMidRoll()) {
							doLog("Slotting in a mid-roll ad with id: " + adSlots[i].id, Debuggable.DEBUG_SEGMENT_FORMATION);
							if(!adSlots[i].isCopy()) {
								if(previousMetrics != currentMetrics && (previousMetrics.usedActiveShowDuration < previousMetrics.totalActiveShowDuration)) {
									// we still have some of the previous show stream to schedule before we do a mid-roll ad for the next stream
									previousMetrics.remainingActiveShowDuration = previousMetrics.totalActiveShowDuration - previousMetrics.usedActiveShowDuration;
									doLog("But first we are slotting in the remaining (previous) show segment to play before mid-roll - segment duration is " + previousMetrics.remainingActiveShowDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
									totalDuration += addRemainingStreamSlice(streams, previousMetrics, "show-c-", totalDuration);	
									previousMetrics.associatedStreamIndex = previousMetrics.associatedStreamIndex + 1;
								}

								if(streams.length > 0) {
									// Add in any streams that we have to play before this ad slot has to be played
									for(var n:int=previousMetrics.associatedStreamIndex; n < adSlots[i].associatedStreamIndex && n < streams.length; n++) {
										doLog("Sequencing stream " + streams[n].filename + " without advertising", Debuggable.DEBUG_SEGMENT_FORMATION);
										addStream(new Stream(this, 
										                     _vastController, 
										                     n, 
										                     "show-cf-" + n + "-" + _sequence.length, 
										                     streams[n].id, //filename, 
										                     "00:00:00", 
										                     Timestamp.timestampToSecondsString(streams[n].duration), 
										                     Timestamp.timestampToSecondsString(streams[n].duration), 
										                     streams[n].reduceLength, 
										                     _baseURL,
														     "any", //mp4
														     "any", //"streaming",
														     "any",
										                     streams[n].playOnce,					
													 		 streams[n].metaData,
													 		 streams[n].autoPlay,
													 		 streams[n].provider,
													 		 streams[n].player,
													 		 null,
													 		 n)); 
										totalDuration += Timestamp.timestampToSeconds(streams[n].duration);
										previousMetrics.associatedStreamIndex = n;
										doLog("Total play duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
									}		

                                	// Slice in the portion of the current program up to the mid-roll ad
									var showSliceDuration:int = adSlots[i].getStartTimeAsSeconds() - currentMetrics.usedActiveShowDuration;
									doLog("Slicing in a segment from the show starting at " + Timestamp.secondsToTimestamp(currentMetrics.usedActiveShowDuration) + " running for " + showSliceDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
									addStream(new Stream(this,
									                     _vastController,
									                     _sequence.length,
									                     "show-d-" + adSlots[i].associatedStreamIndex + "-" + _sequence.length,
									                     streams[adSlots[i].associatedStreamIndex].id, //filename, 
													     Timestamp.secondsToTimestamp(currentMetrics.usedActiveShowDuration),
														 new String(showSliceDuration),
													     new String(currentMetrics.totalActiveShowDuration),
														 true,
														 _baseURL,
													     "any", //mp4
													     "any", //"streaming",
													     "any",
														 streams[adSlots[i].associatedStreamIndex].playOnce,
														 streams[adSlots[i].associatedStreamIndex].metaData,
												 		 streams[adSlots[i].associatedStreamIndex].autoPlay,
														 streams[adSlots[i].associatedStreamIndex].provider,
														 streams[adSlots[i].associatedStreamIndex].player,
												 		 null,
														 adSlots[i].associatedStreamIndex)); 
									currentMetrics.usedActiveShowDuration += showSliceDuration;
									totalDuration += showSliceDuration;
									doLog("Total play duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
								}
							}
						}
						else { // it's post-roll 
							doLog("Slotting in a post-roll ad with id: " + adSlots[i].id, Debuggable.DEBUG_SEGMENT_FORMATION);
							if(streams.length > 0) {
								if(!adSlots[i].isCopy()) {		
									if(currentMetrics.associatedStreamIndex != previousMetrics.associatedStreamIndex) {
										if((previousMetrics.usedActiveShowDuration > 0) && previousMetrics.usedActiveShowDuration < previousMetrics.totalActiveShowDuration) {
											// we still have some of the previous show stream to schedule before we do a pre-roll ad for the next stream
											previousMetrics.remainingActiveShowDuration = previousMetrics.totalActiveShowDuration - previousMetrics.usedActiveShowDuration;
											doLog("Slotting in the remaining (previous) show segment to play before pre-roll - segment duration is " + previousMetrics.remainingActiveShowDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
											totalDuration += addRemainingStreamSlice(streams, previousMetrics, "show-h-", totalDuration);
										}
		                                
										// Add in any streams that we have to play before this ad slot has to be played
										var startIndex:int = (i == 0) ? previousMetrics.associatedStreamIndex : previousMetrics.associatedStreamIndex+1;
										for(var o:int=startIndex; o < adSlots[i].associatedStreamIndex && o < streams.length; o++) {
											doLog("Sequencing stream " + streams[o].filename + " without advertising", Debuggable.DEBUG_SEGMENT_FORMATION);
											addStream(new Stream(this, 
											                     _vastController, 
											                     o, 
											                     "show-hf-" + o + "-" + _sequence.length, 
											                     streams[o].id, //filename, 
											                     "00:00:00", 
											                     Timestamp.timestampToSecondsString(streams[o].duration), 
											                     Timestamp.timestampToSecondsString(streams[o].duration), 
											                     streams[o].reduceLength, 
											                     _baseURL,
															     "any", //mp4
															     "any", //"streaming",
															     "any",
											                     streams[o].playOnce,					
														 		 streams[o].metaData,
														 		 streams[o].autoPlay,
														 		 streams[o].provider,
														 		 streams[o].player,
														 		 null,
														 		 o)); 
											totalDuration += Timestamp.timestampToSeconds(streams[o].duration);
											previousMetrics.associatedStreamIndex = o;
											doLog("Total play duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
										}		
									}

									// now slot in the show before the post-roll
									currentMetrics.remainingActiveShowDuration = currentMetrics.totalActiveShowDuration - currentMetrics.usedActiveShowDuration;
									if(currentMetrics.remainingActiveShowDuration > 0) {
										doLog("Slotting in the remaining show segment to play before post-roll - start point is " + Timestamp.secondsToTimestamp(currentMetrics.usedActiveShowDuration) + ", segment duration is " + currentMetrics.remainingActiveShowDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
										totalDuration += addRemainingStreamSlice(streams, currentMetrics, "show-e-", totalDuration);
										if(i+1 < adSlots.length) {
											currentMetrics.associatedStreamIndex = currentMetrics.associatedStreamIndex + 1;
										}
									}
								}
							}		
						}

						doLog("Inserting ad to play for " + adSlots[i].duration + " seconds from " + totalDuration + " seconds into the stream", Debuggable.DEBUG_SEGMENT_FORMATION);
						adSlots[i].streamStartTime = 0;
						adSlots[i].parent = this;
						addStream(adSlots[i]);
						currentMetrics.usedAdDuration += adSlots[i].getDurationAsInt();
						doLog("Have slotted in the ad with id " + adSlots[i].id, Debuggable.DEBUG_SEGMENT_FORMATION);
						totalDuration += adSlots[i].getDurationAsInt();
						doLog("Total stream duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
					}
					else {
						doLog("Ad slot " + adSlots[i].id + " is not linear/pop or is not active - active is " + adSlots[i].isActive(), Debuggable.DEBUG_SEGMENT_FORMATION);
						adSequence.adSlots[i].associatedStreamStartTime = totalDuration;
					}	
				}
				if(currentMetrics.usedActiveShowDuration < currentMetrics.totalActiveShowDuration) { 
					// After looping through all the ads, we still have some show to play, so add it in
					currentMetrics.remainingActiveShowDuration = currentMetrics.totalActiveShowDuration - currentMetrics.usedActiveShowDuration;
					doLog("Slotting in the remaining show segment right at the end - segment duration is " + currentMetrics.remainingActiveShowDuration + " seconds", Debuggable.DEBUG_SEGMENT_FORMATION);
					totalDuration += addRemainingStreamSlice(streams, currentMetrics, "show-f", totalDuration);								
				}
				
				if(currentMetrics.associatedStreamIndex+1 < streams.length) {
					// there are still some streams to sequence after all the ads have been slotted in
					for(var x:int=currentMetrics.associatedStreamIndex+1; x < streams.length; x++) {
						doLog("Sequencing remaining stream " + streams[x].filename + " without any advertising at all", Debuggable.DEBUG_SEGMENT_FORMATION);
						addStream(new Stream(this, 
						                     _vastController, 
						                     x, 
						                     "show-g-" + x, 
						                     streams[x].id, //filename, 
						                     "00:00:00", 
						                     Timestamp.timestampToSecondsString(streams[x].duration), 
						                     Timestamp.timestampToSecondsString(streams[x].duration), 
						                     streams[x].reduceLength, 
						                     _baseURL, 
										     "any", //mp4
										     "any", //"streaming",
										     "any",
						                     streams[x].playOnce,					
									 		 streams[previousMetrics.associatedStreamIndex].metaData,
									 		 streams[previousMetrics.associatedStreamIndex].autoPlay,
									 		 streams[previousMetrics.associatedStreamIndex].provider,
									 		 streams[previousMetrics.associatedStreamIndex].player,
									 		 null,
									 		 previousMetrics.associatedStreamIndex)); 
						totalDuration += Timestamp.timestampToSeconds(streams[x].duration);
						doLog("Total play duration is now " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
					}
				}
//				}
			}
			else { // we don't have any ads, so just stream the main show
				doLog("No video ad streams to schedule, just scheduling the main stream(s)", Debuggable.DEBUG_SEGMENT_FORMATION);
				for(var j:int=0; j < streams.length; j++) {
					doLog("Sequencing stream " + streams[j].filename + " without any advertising at all", Debuggable.DEBUG_SEGMENT_FORMATION);
					addStream(new Stream(this, 
					                     _vastController, 
					                     j, 
					                     "show-h-" + j, 
					                     streams[j].id, //filename, 
					                     "00:00:00", 
					                     Timestamp.timestampToSecondsString(streams[j].duration), 
					                     Timestamp.timestampToSecondsString(streams[j].duration), 
					                     streams[j].reduceLength, 
					                     _baseURL,
									     "any", //mp4
									     "any", //"streaming",
									     "any",
					                     streams[j].playOnce,					
								 		 streams[previousMetrics.associatedStreamIndex].metaData,
								 		 streams[previousMetrics.associatedStreamIndex].autoPlay,
								 		 streams[previousMetrics.associatedStreamIndex].provider,
								 		 streams[previousMetrics.associatedStreamIndex].player,
								 		 null,
								 		 previousMetrics.associatedStreamIndex)); 
					totalDuration += Timestamp.timestampToSeconds(streams[j].duration);
				}
			}
            
            if(previewImage != null && _sequence.length > 0) {
            	// add the preview image property to the first stream in the sequence
            	_sequence[0].previewImage = previewImage;
            	doLog("Have set preview image on first stream - image is: " + previewImage, Debuggable.DEBUG_SEGMENT_FORMATION);
            }
            
			doLog("Total (Final) stream duration is  " + totalDuration, Debuggable.DEBUG_SEGMENT_FORMATION);
			doLogAndTrace("*** STREAM SEQUENCE BUILT - " + _sequence.length + " STREAMS INDEXED ", _sequence, Debuggable.DEBUG_SEGMENT_FORMATION);
			return totalDuration;
		}				

        public function processTimeEvent(associatedStreamIndex:int, timeEvent:TimeEvent, includeChildLinearPoints:Boolean=true):void {
        	if(associatedStreamIndex < _sequence.length) {
        		_sequence[associatedStreamIndex].processTimeEvent(timeEvent, includeChildLinearPoints);
        		_lastTrackedStreamIndex = associatedStreamIndex;
        	}
        }

		public function resetRepeatableTrackingPoints(streamIndex:int):void {
			if(streamIndex < _sequence.length) {
				_sequence[streamIndex].resetRepeatableTrackingPoints();				
			}
		}
        	
        public function findSegmentRunningAtTime(time:Number):Stream {
        	var timeSpent:int = 0;
			for(var i:int = 0; i < _sequence.length; i++) {
				timeSpent += _sequence[i].getDurationAsInt();
				if(timeSpent > time) {
					return _sequence[i];
				}
			}
			return null; 	
        }

        public function processPauseEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processPauseStream();	
        	}
        }

        public function processPauseEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processPauseStream();
        	}
        }
		
        public function processResumeEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processResumeStream();
        	}
        }

        public function processResumeEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processResumeStream();
        	}
        }

        public function processStopEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processStopStream();
        	}
        }

        public function processStopEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processStopStream();
        	}
        }

        public function processFullScreenEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processFullScreenEvent();
        	}
        }

        public function processFullScreenEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processFullScreenEvent();
        	}
        }

        public function processMuteEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processMuteEvent();
        	}
        }

        public function processMuteEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processMuteEvent();
        	}
        }        
        
        public function processUnmuteEvent(time:Number):void {
        	var stream:Stream = findSegmentRunningAtTime(time);
        	if(stream != null) {
        		stream.processUnmuteEvent();
        	}
        }

        public function processUnmuteEventForStream(streamIndex:int):void {
        	if(streamIndex < _sequence.length) {
        		_sequence[streamIndex].processUnmuteEvent();
        	}
        }                
	}
}