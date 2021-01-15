//
//  ViewController.swift
//  GanGImage
//
//  Created by won on 2020/06/08.
//  Copyright © 2020 won. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var animatedImageView: YYAnimatedImageView = {
        let v = YYAnimatedImageView()
        v.image = YYImage(named: "heart")
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    var webPDecoder: WebPDecoder?

    @IBAction func startAnimating(_ sender: UIButton) {
        animatedImageView.currentAnimatedImageIndex = 0
        animatedImageView.startAnimating()
        webPDecoder = .init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(animatedImageView)

        NSLayoutConstraint.activate([
            animatedImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animatedImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animatedImageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            animatedImageView.heightAnchor.constraint(equalTo: animatedImageView.widthAnchor),
            animatedImageView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }
}

extension UIImage {
    
}
