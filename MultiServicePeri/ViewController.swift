//
//  ViewController.swift
//  MultiServicePeri
//
//  Created by Jay Tucker on 2/5/18.
//  Copyright © 2018 Imprivata. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textView: UITextView!
    
    let bluetoothMananger = BluetoothManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        log("viewDidLoad")
        
        tableView.dataSource = self
        tableView.delegate = self
        
        textView.font = UIFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .medium)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: .UIApplicationWillResignActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appendMessage(_:)), name: NSNotification.Name(rawValue: newMessageNotificationName), object: nil)
        
        bluetoothMananger.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        log("viewDidAppear")
        
        let launchOptions = (UIApplication.shared.delegate as! AppDelegate).launchOptions
        log("launchOptions \(launchOptions ?? [:])")
    }
    
    @objc func switchChanged(_ sender : UISwitch) {
        log("service \(sender.tag) turned \(sender.isOn ? "ON" : "OFF")")
        if sender.isOn {
            bluetoothMananger.startService(index: sender.tag)
        } else {
            bluetoothMananger.stopService(index: sender.tag)
        }
    }
    
    @objc func didBecomeActive() {
        log("didBecomeActive")
    }
    
    @objc func willResignActive() {
        log("willResignActive")
    }
    
    @objc func appendMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let text = userInfo["text"] as? String else { return }
        DispatchQueue.main.async {
            let newText = self.textView.text + "\n" + text
            self.textView.text = newText
            self.textView.scrollRangeToVisible(NSRange(location: newText.count, length: 0))
        }
    }
    
}

extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bluetoothMananger.serviceCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "serviceCell", for: indexPath)
        let row = indexPath.row
        let text = "Service \(row)"
        cell.textLabel?.text = text
        
        let switchView = UISwitch(frame: .zero)
        switchView.setOn(false, animated: true)
        switchView.tag = indexPath.row
        switchView.addTarget(self, action: #selector(self.switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = switchView
        
        return cell
    }
    
}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let cell = tableView.cellForRow(at: indexPath)!
        let switchView = cell.accessoryView as! UISwitch
        switchView.setOn(!switchView.isOn, animated: true)
        switchChanged(switchView)
    }
    
}

extension ViewController: BluetoothManagerDelegate {

    func servicesDidChange(_ indices: [Int]) {
        log("servicesDidChange \(indices)")
        for index in indices {
            let indexPath = IndexPath(row: index, section: 0)
            let cell = tableView.cellForRow(at: indexPath)!
            let switchView = cell.accessoryView as! UISwitch
            switchView.setOn(true, animated: false)
        }
    }
    
}
