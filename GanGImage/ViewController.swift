//
//  ViewController.swift
//  GanGImage
//
//  Created by won on 2020/06/08.
//  Copyright © 2020 won. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var imageView: YYAnimatedImageView = {
        let v = YYAnimatedImageView()
        v.image = YYImage(named: "heart")
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    @IBAction func startAnimating(_ sender: UIButton) {
        imageView.currentAnimatedImageIndex = 0
        imageView.startAnimating()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }
}

