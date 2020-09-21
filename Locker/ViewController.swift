//
//  ViewController.swift
//  Locker
//
//  Created by Dmitry Borodin on 20.09.2020.
//  Copyright © 2020 Dmitry Borodin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - Properties
    
    var contentView: MainView { view as! MainView }
    let cryptoManager = CryptoManager(name: "SecretMessage")
    
    private var removeKeyBarButtonItem: UIBarButtonItem!
    
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = MainView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Locker"
        navigationController?.navigationBar.prefersLargeTitles = true
        addRemoveKeyButton()
        setButtons()
        setInputViews()
        addPasteboardObserver()
    }
    
    
    // MARK: - Prepare methods
    
    private func addRemoveKeyButton() {
        let barButtonItem = UIBarButtonItem(title: "Remove key", style: .plain, target: self, action: #selector(removeKeyBarButtonTapped))
        navigationItem.rightBarButtonItem = barButtonItem
        self.removeKeyBarButtonItem = barButtonItem
        updateRemoveKeyBarButton()
    }
    
    private func setButtons() {
        // Input buttons (encrypt and decrypt)
        let hasInputText = !(contentView.inputTextField.text?.isEmpty ?? true)
        inputButtonsIsEnabled(hasInputText)
        contentView.encodeButton.addTarget(self, action: #selector(encryptButtonTapped), for: .touchUpInside)
        contentView.decodeButton.addTarget(self, action: #selector(decryptButtonTapped), for: .touchUpInside)
        
        // Output buttons (copy and clear)
        let hasOutputText = !(contentView.outputTextView.text?.isEmpty ?? true)
        outputControlsIsHidden(!hasOutputText)
        contentView.copyButton.setTitle("Copied", for: .disabled)
        contentView.copyButton.addTarget(self, action: #selector(copyResultButtonTapped), for: .touchUpInside)
        contentView.clearButton.addTarget(self, action: #selector(clearResultButtonTapped), for: .touchUpInside)
    }
    
    private func setInputViews() {
        contentView.inputTextField.delegate = self
    }
    
    private func addPasteboardObserver() {
        let center = NotificationCenter.default
        // Add observer for pasteboard changes to update state of Copy result button
        center.addObserver(self, selector: #selector(pasteboardDidChange), name: UIPasteboard.changedNotification, object: nil)
    }
    
    
    // MARK: - Action methods
    
    @objc
    private func removeKeyBarButtonTapped(_ sender: UIBarButtonItem) {
        // Prepare alert to ask if the user really wants to remove key
        let message = "Are you sure you want to remove key? You will not be able to decrypt encrypted data"
        let alert = UIAlertController(title: "Remove key?", message: message, preferredStyle: .alert)
        let removeAction = UIAlertAction(title: "Remove", style: .destructive) { [weak self] (_) in
            // remove key
            self?.cryptoManager.removeKey()
            // update state of the bar button
            self?.updateRemoveKeyBarButton()
            
            self?.contentView.outputTextView.text = ""
            self?.outputControlsIsHidden(true)
            let hasInputText = !(self?.contentView.inputTextField.text?.isEmpty ?? true)
            self?.inputButtonsIsEnabled(hasInputText)
        }
        alert.addAction(removeAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    @objc
    private func encryptButtonTapped(_ sender: UIButton) {
        // Check if there is a text to encrypt
        guard let textToEncrypt = contentView.inputTextField.text, !textToEncrypt.isEmpty else { return }
        cryptoManager.encrypt(string: textToEncrypt) { [weak self] (result) in
            switch result {
            case .success(let encryptedText):
                // Text successfully encrypted. Update UI
                self?.contentView.outputTextView.text = encryptedText
                self?.outputControlsIsHidden(encryptedText.isEmpty)
                self?.contentView.copyButton.isEnabled = true
                self?.updateRemoveKeyBarButton()
                
            case .failure(let error):
                self?.showErrorAlert(with: error.localizedDescription)
                
            }
        }
    }
    
    @objc
    private func decryptButtonTapped(_ sender: UIButton) {
        // Check if there is a text to decrypt
        guard let textToDecrypt = contentView.inputTextField.text, !textToDecrypt.isEmpty else { return }
        cryptoManager.decrypt(base64String: textToDecrypt) { [weak self] (result) in
            switch result {
            case .success(let decryptedText):
                // Text successfully decrypted. Update UI
                self?.contentView.outputTextView.text = decryptedText
                self?.outputControlsIsHidden(decryptedText.isEmpty)
                self?.contentView.copyButton.isEnabled = true
                self?.updateRemoveKeyBarButton()
                
            case .failure(let error):
                self?.showErrorAlert(with: error.localizedDescription)
                
            }
        }
    }
    
    @objc
    private func copyResultButtonTapped(_ sender: UIButton) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = contentView.outputTextView.text
    }
    
    @objc
    private func clearResultButtonTapped(_ sender: UIButton) {
        contentView.outputTextView.text = ""
        outputControlsIsHidden(true)
    }
    
    @objc
    private func pasteboardDidChange(_ notification: Notification) {
        // Make sure this is a correct notification
        guard notification.name == UIPasteboard.changedNotification else { return }
        guard
            let currentOutputText = contentView.outputTextView.text,
            !currentOutputText.isEmpty,
            let newCopiedText = UIPasteboard.general.string else { return }
        
        // Check if current output text is copied
        let isCopiedOutputResult = currentOutputText == newCopiedText
        // Update copy result button
        contentView.copyButton.isEnabled = !isCopiedOutputResult
    }
    
    
    // MARK: - Helper methods
    
    private func showErrorAlert(with message: String?) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
    
    private func inputButtonsIsEnabled(_ isEnabled: Bool) {
        contentView.encodeButton.isEnabled = isEnabled
        let hasKey = cryptoManager.hasKey()
        contentView.decodeButton.isEnabled = isEnabled && hasKey
    }
    
    private func outputControlsIsHidden(_ isHidden: Bool) {
        contentView.copyButton.isHidden = isHidden
        contentView.clearButton.isHidden = isHidden
    }
    
    private func updateRemoveKeyBarButton() {
        let hasKey = cryptoManager.hasKey()
        removeKeyBarButtonItem.isEnabled = hasKey
    }
    
}


// MARK: - Text field delegate

extension ViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Make sure it is needed text field
        guard textField == contentView.inputTextField else { return true }
        // get old text
        let oldText = textField.text as NSString?
        // get future text after editing
        let newText = oldText?.replacingCharacters(in: range, with: string)
        let hasText = !(newText?.isEmpty ?? true)
        // update UI
        inputButtonsIsEnabled(hasText)
        
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Separate method for clear text button, because the button does not
        // trigger method `textField(_:shouldChangeCharactersIn:replacementString:)`
        guard textField == contentView.inputTextField else { return true }
        contentView.encodeButton.isEnabled = false
        contentView.decodeButton.isEnabled = false
        
        return true
    }
}
