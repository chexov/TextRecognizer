//
//  ViewController.swift
//  TextRecognizer
//
//  Created by Martin Mitrevski on 03.10.17.
//  Copyright © 2017 Mitrevski. All rights reserved.
//

import UIKit
import CoreML
import Vision
import SwiftOCR

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var detectedText: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var model: VNCoreMLModel!

    let swiftOCRInstance = SwiftOCR()

    var ocrText = "";
    var textMetadata = [Int: [Int: String]]()
    var newImage: UIImage!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadModel()
        activityIndicator.hidesWhenStopped = true
    }

    private func loadModel() {
        model = try? VNCoreMLModel(for: Alphanum_28x28().model)
    }

    // MARK: IBAction

    @IBAction func pickImageClicked(_ sender: UIButton) {
        let alertController = createActionSheet()
        let action1 = UIAlertAction(title: "Camera", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.showImagePicker(withType: .camera)
        })
        let action2 = UIAlertAction(title: "Photos", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.showImagePicker(withType: .photoLibrary)
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        addActionsToAlertController(controller: alertController,
                actions: [action1, action2, cancelAction])
        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: image picker

    func showImagePicker(withType type: UIImagePickerControllerSourceType) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = type
        present(pickerController, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String: Any]) {
        dismiss(animated: true)
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("Couldn't load image")
        }
        let newImage = fixOrientation(image: image)
        self.imageView.image = newImage
        clearOldData()
        showActivityIndicator()
        DispatchQueue.global(qos: .userInteractive).async {
            self.detectText(image: newImage)
        }
    }

    // MARK: text detection

    func detectText(image: UIImage) {
        self.ocrText = "";
        var numberOfWords = 0
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        let context = UIGraphicsGetCurrentContext()
        image.draw(at: CGPoint(x: 0, y: 0))

        let convertedImage = image |> adjustColors |> convertToGrayscale
        let handler = VNImageRequestHandler(cgImage: convertedImage.cgImage!)
        let request: VNDetectTextRectanglesRequest =
                VNDetectTextRectanglesRequest(completionHandler: { [unowned self] (request, error) in
                    if (error != nil) {
                        print("Got Error In Run Text Dectect Request :(")
                    } else {
                        guard let results = request.results as? Array<VNTextObservation> else {
                            fatalError("Unexpected result type from VNDetectTextRectanglesRequest")
                        }
                        if (results.count == 0) {
                            self.handleEmptyResults()
                            return
                        }


                        for textObservation in results {
                            let croppedImage = crop(image: image, boundingBox: textObservation.boundingBox)
                            let grayScaleImage = convertToGrayscale(image: croppedImage!)

                            let boundingBox = textObservation.boundingBox;
                            var t: CGAffineTransform = CGAffineTransform.identity;
                            t = t.scaledBy(x: image.size.width, y: -image.size.height);
                            t = t.translatedBy(x: 0, y: -1);
                            let x = boundingBox.applying(t).origin.x
                            let y = boundingBox.applying(t).origin.y
                            let width = boundingBox.applying(t).width
                            let height = boundingBox.applying(t).height

                            let colorSpace = CGColorSpaceCreateDeviceRGB()
                            context?.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0, 0, 1, 1])!)
                            context?.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0, 1, 0.42])!)
                            context?.setLineWidth(1)
                            context?.addRect(CGRect(x: x, y: y, width: width, height: height))
                            context?.drawPath(using: .fill)


                            self.swiftOCRInstance.recognize(grayScaleImage) {
                                recognizedString in
                                print("ocr=" + recognizedString as String)
                                self.ocrText = self.ocrText + "; " + recognizedString as String;
                                self.handleResult2()
                            }


                        }

                        self.newImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()
                        DispatchQueue.main.async {
                            self.imageView.image = self.newImage
                        }
                    }
                })
        request.reportCharacterBoxes = true
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }

    func handleEmptyResults() {
        DispatchQueue.main.async {
            self.hideActivityIndicator()
            self.detectedText.text = "The image does not contain any text."
        }

    }

    func classifyImage(image: UIImage, wordNumber: Int, characterNumber: Int) {
        swiftOCRInstance.recognize(image) {
            recognizedString in
            print(recognizedString)
            self.ocrText = recognizedString;
            self.handleResult2()
//            self.detectedText.text = recognizedString
        }

//        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
//            guard let results = request.results as? [VNClassificationObservation],
//                let topResult = results.first else {
//                    fatalError("Unexpected result type from VNCoreMLRequest")
//            }
//            let result = topResult.identifier
//            let classificationInfo: [String: Any] = ["wordNumber" : wordNumber,
//                                                     "characterNumber" : characterNumber,
//                                                     "class" : result]
//            self?.handleResult(classificationInfo)
//        }

//        guard let ciImage = CIImage(image: image) else {
//            fatalError("Could not convert UIImage to CIImage :(")
//        }
//        let handler = VNImageRequestHandler(ciImage: ciImage)
//        DispatchQueue.global(qos: .userInteractive).async {
//            do {
//                try handler.perform([request])
//            }
//            catch {
//                print(error)
//            }
//        }
    }

    func handleResult2() {
        objc_sync_enter(self)

        objc_sync_exit(self)
        DispatchQueue.main.async {
            self.hideActivityIndicator()
            self.showDetectedText()
        }
    }

    func handleResult(_ result: [String: Any]) {
        objc_sync_enter(self)
        guard let wordNumber = result["wordNumber"] as? Int else {
            return
        }
        guard let characterNumber = result["characterNumber"] as? Int else {
            return
        }
        guard let characterClass = result["class"] as? String else {
            return
        }
        if (textMetadata[wordNumber] == nil) {
            let tmp: [Int: String] = [characterNumber: characterClass]
            textMetadata[wordNumber] = tmp
        } else {
            var tmp = textMetadata[wordNumber]!
            tmp[characterNumber] = characterClass
            textMetadata[wordNumber] = tmp
        }
        objc_sync_exit(self)
        DispatchQueue.main.async {
            self.hideActivityIndicator()
            self.showDetectedText()
        }
    }

    func showDetectedText() {
        var result: String = ""
        if (textMetadata.isEmpty) {
            detectedText.text = "The image does not contain any text."
            detectedText.text = ocrText
            return
        }
        let sortedKeys = textMetadata.keys.sorted()
        for sortedKey in sortedKeys {
            result += word(fromDictionary: textMetadata[sortedKey]!) + " "
        }
        detectedText.text = ocrText
        detectedText.text = result
    }

    func word(fromDictionary dictionary: [Int: String]) -> String {
        let sortedKeys = dictionary.keys.sorted()
        var word: String = ""
        for sortedKey in sortedKeys {
            let char: String = dictionary[sortedKey]!
            word += char
        }
        return word
    }

    // MARK: private

    private func clearOldData() {
        detectedText.text = ""
        textMetadata = [:]
    }

    private func showActivityIndicator() {
        activityIndicator.startAnimating()
    }

    private func hideActivityIndicator() {
        activityIndicator.stopAnimating()
    }


}

