/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import CoreImage
import Vision

class ImageProcessor {
  var frameBuffer: [CIImage] = []
  var alignedFrameBuffer: [CIImage] = []
  var isProcessingFrame = false
  
  var frameCount: Int {
    return frameBuffer.count
  }
  
  var completion: ((CIImage) -> Void)?
  
  func add(_ frame: CIImage) {
    if isProcessingFrame {
      return
    }
    
    frameBuffer.append(frame)
  }
  
  func processFrame(completion: ((CIImage) -> Void)?) {
    isProcessingFrame = true
    self.completion = completion
    
    let firstFrame = frameBuffer.removeFirst()
    alignedFrameBuffer.append(firstFrame)
    
    for frame in frameBuffer {
      let request = VNTranslationalImageRegistrationRequest(targetedCIImage: frame)
      
      do {
        let sequenceHandler = VNSequenceRequestHandler()
        
        try sequenceHandler.perform([request], on: firstFrame)
      } catch {
        print(error.localizedDescription)
      }
      
      alignImages(request: request, frame: frame)
    }
    
    combineFrames()
  }
  
  func alignImages(request: VNRequest, frame: CIImage) {
    guard let results = request.results as? [VNImageTranslationAlignmentObservation], let result = results.first else { return }
    
    let alignedFrame = frame.transformed(by: result.alignmentTransform)
    
    alignedFrameBuffer.append(alignedFrame)
  }
  
  func cleanup(image: CIImage) {
    frameBuffer = []
    alignedFrameBuffer = []
    isProcessingFrame = false
    
    if let completion = completion {
      DispatchQueue.main.async {
        completion(image)
      }
    }
    
    completion = nil
  }
  
  func combineFrames() {
    var finalImage = alignedFrameBuffer.removeFirst()
    
    let filter = AverageStackingFilter()
    
    for (i, image) in alignedFrameBuffer.enumerated() {
      filter.inputCurrentStack = finalImage
      filter.inputNewImage = image
      filter.inputStackCount = Double(i + 1)
      
      finalImage = filter.outputImage()!
    }
    
    cleanup(image: finalImage)
  }
}
