//
//  MainView.swift
//  Locker
//
//  Created by Dmitry Borodin on 21.09.2020.
//  Copyright © 2020 Dmitry Borodin. All rights reserved.
//

import UIKit

class MainView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.text = "What do you want to encrypt or decrypt?"
        return label
    }()
    
    lazy var inputTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .always
        textField.placeholder = "Text to encrypt or decrypt"
        return textField
    }()
    
    lazy var encodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Encrypt", for: .normal)
        return button
    }()
    
    lazy var decodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Decrypt", for: .normal)
        return button
    }()
    
    lazy var outputTextView: UITextView = {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = false
        return textView
    }()
    
    lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy result", for: .normal)
        return button
    }()
    
    lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear result", for: .normal)
        return button
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func setView() {
        backgroundColor = .systemBackground
        
        // create stack view for input buttons
        let buttonsStackView = UIStackView(arrangedSubviews: [encodeButton, decodeButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        
        let subviews = [
            titleLabel,
            inputTextField,
            buttonsStackView,
            outputTextView,
            copyButton,
            clearButton
        ]
        
        subviews.forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        NSLayoutConstraint.activate([
            // set title label
            titleLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
            // set input text field
            inputTextField.heightAnchor.constraint(equalToConstant: 34),
            inputTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            inputTextField.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            inputTextField.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
            // set input buttons
            buttonsStackView.heightAnchor.constraint(equalToConstant: 44),
            buttonsStackView.topAnchor.constraint(equalTo: inputTextField.bottomAnchor, constant: 16),
            buttonsStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            buttonsStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
            // set output text view
            outputTextView.topAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: 32),
            outputTextView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            outputTextView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            outputTextView.heightAnchor.constraint(equalToConstant: 90),
            
            // set copy button
            copyButton.topAnchor.constraint(equalTo: outputTextView.bottomAnchor, constant: 16),
            copyButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // clear button
            clearButton.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 16),
            clearButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
