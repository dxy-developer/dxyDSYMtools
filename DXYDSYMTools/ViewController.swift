//
//  ViewController.swift
//  DXYDSYMTools
//
//  Created by HamGuy on 4/22/15.
//  Copyright (c) 2015 HamGuy. All rights reserved.
//

import Cocoa


extension String {
    var length: Int {
        return count(self)
    }// Swift 1.2
}

class ViewController: NSViewController,NSTableViewDataSource,NSTableViewDelegate {

    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var addrFiled: NSTextField!
    @IBOutlet weak var dsymFilePathFileld: NSTextField!
    @IBOutlet weak var archSeletor: NSMatrix!
    @IBOutlet weak var slideaddrField: NSTextField!
    @IBOutlet weak var uudiLabel: NSTextField!
    
    @IBOutlet weak var conditionView: NSView!
    @IBOutlet weak var resultView: NSView!
    @IBOutlet weak var resultLabel: NSTextField!
    
    var targetFilePath:String = ""
    
    var errorAddrList:NSMutableArray = []
    var archDict : NSMutableDictionary = NSMutableDictionary()
    
    var cachedAddr : NSArray = [];
    var cachedSlideAddr :String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.whiteColor().CGColor
        
        conditionView.hidden = true
        resultView.hidden = true
        
        conditionView.wantsLayer = true
        conditionView.layer?.borderColor = NSColor.lightGrayColor().CGColor
        conditionView.layer?.borderWidth = 1
        
        resultView.wantsLayer = true
        resultView.layer?.borderColor = NSColor.lightGrayColor().CGColor
        resultView.layer?.borderWidth = 1
//        archSeletor

    }
    

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: - Tableview
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return errorAddrList.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellView: NSTableCellView = tableView.makeViewWithIdentifier(tableColumn!.identifier, owner: self) as! NSTableCellView
        
        var frame = cellView.frame
        frame.size.width = 200
        cellView.textField!.frame = frame

        
        if tableColumn!.identifier == "erroraddrcolumn"{
            let addr = self.errorAddrList[row] as! String
            cellView.textField!.stringValue = addr
            return cellView
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        let row = tableView.selectedRow
        let addr: String = errorAddrList[row] as! String
        if !validateCondition() || addr.length == 0{
            return
        }
        findPossibleError([addr])
    }
    
    // MARK: - Actions
    
    @IBAction func addErrorAddr(sender: AnyObject) {
        if addrFiled.stringValue.length==0 || !addrFiled.stringValue.hasPrefix("0x"){
            return
        }
        if !errorAddrList.containsObject(addrFiled.stringValue){
        errorAddrList.addObject(addrFiled.stringValue)
        tableView.reloadData()
            addrFiled.stringValue = ""
        }
        
    }

    @IBAction func chooseDSYMFile(sender: AnyObject) {
        slideaddrField.stringValue = ""
        cachedAddr = []
        cachedSlideAddr = ""
        errorAddrList.removeAllObjects()
        archDict.removeAllObjects()
        resultLabel.stringValue = ""
        uudiLabel.stringValue = ""
        
        openfiledialog("选择dSYM文件", filetypelist: "dSYM") { (path) -> Void in
            if(path.length>0){
                self.archSeletor.selectTextAtRow(0, column: 0)
                self.conditionView.hidden = false
                self.dsymFilePathFileld.stringValue = path
                self.getInfoFormDSYMFile(path)
                self.selectedChanged(self.archSeletor)
            }
        }
        
    }
    
    @IBAction func chenckError(sender: AnyObject) {
        if !validateCondition(){
            return
        }
        
        findPossibleError(errorAddrList as NSArray as! [String])
    }
    
    @IBAction func selectedChanged(sender:NSMatrix){
       
        if cachedAddr.count>0{
           let tmpAddrList = errorAddrList;
            errorAddrList = cachedAddr.mutableCopy() as! NSMutableArray
            cachedAddr = tmpAddrList.copy() as! NSArray
            
           
        }else{
            cachedAddr = errorAddrList.copy() as! NSArray
            errorAddrList.removeAllObjects()
        }
        
        if cachedSlideAddr.length > 0 {
            let tmpSlideAddr = slideaddrField.stringValue
            slideaddrField.stringValue = cachedSlideAddr
            cachedSlideAddr = tmpSlideAddr
        }else{
            cachedSlideAddr = slideaddrField.stringValue
            slideaddrField.stringValue = ""
            println(cachedSlideAddr)
        }
        
        
        tableView.reloadData()
        let type = sender.selectedTag() == 0 ? "armv7" : "arm64";
        uudiLabel.stringValue = (archDict[type] as! [String])[0]
    }
    
    // MARK: - Private
    func matchString(string:String,pattern:String)->String?{
        var regex = NSRegularExpression(pattern: pattern, options: nil, error: nil)
        let result = regex?.firstMatchInString(string, options: nil, range: NSMakeRange(0, string.length))
        return (string as NSString).substringWithRange(result!.range)
    }
    
    func findType(info:[String])->String{
        var type = info[2] as NSString
        type = type.substringWithRange(NSMakeRange(1, type.length-2))
        return type as String
    }
    
    func findUUIDString(info:[String])->String{
        let uuid = info[1]
        return uuid
    }
    
    func getInfoFormDSYMFile(filePath:String){
        archDict.removeAllObjects()
        var path = (filePath as NSString).substringFromIndex("file:\\\\".length)
        let commandOutput = executeCommand("/usr/bin/dwarfdump", args: ["--uuid",path]) as String
        println("Command output: \(commandOutput)")
        var array = commandOutput.componentsSeparatedByString("\n")
        
        for aString in array{
            if aString.length>0{
                let tmpArray = aString.componentsSeparatedByString(" ")
                let type = findType(tmpArray)
                if type.length>0{
                    let uuid = tmpArray[1] as String
                    let fileName = tmpArray[3] as String
                    archDict.setValue([uuid,fileName], forKey: type)
                }
            }
        }

    }
    
    func findPossibleError(errorAddr:[String]){
        if (archSeletor.selectedColumn == NSNotFound){
            return;
        }
        let arch = archSeletor.selectedColumn == 0 ? "armv7" : "arm64"
        let infos = archDict[arch] as! [String]
        targetFilePath = infos[1]
        var argmentArray:[String] = ["-arch",arch,"-o",targetFilePath,"-l",slideaddrField.stringValue]
        for addr in errorAddr{
            argmentArray.append(addr)
        }
        let commandOutput = executeCommand("/usr/bin/atos", args: argmentArray) as String
        if commandOutput.length>0{
            resultView.hidden = false
            resultLabel.stringValue = commandOutput
        }
    }
    
    func validateCondition()->Bool{
        var result = true;
        
        if errorAddrList.count == 0{
            var alert = NSAlert();
            alert.informativeText = "警告"
            alert.messageText! = "错误地址列表不能为空！"
            alert.runModal()
            return false
        }
        
        if slideaddrField.stringValue.length == 0{
            var alert = NSAlert();
            alert.informativeText = "警告"
            alert.messageText! = "Slide Address 不能为空！"
            alert.runModal()
            return false
        }
        return result;
    }
    
    // MARK: - Helper
    func executeCommand(command: String, args: [String]) -> String {
        
        let task = NSTask()
        
        task.launchPath = command
        task.arguments = args
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
        
        return output
        
    }
    
    func openfiledialog (windowTitle: String,filetypelist: String,completion:(path:String)->Void)
    {
        var openPanel: NSOpenPanel = NSOpenPanel()
        var fileTypeArray: [String] = filetypelist.componentsSeparatedByString(",")
        
        openPanel.prompt = "Open"
        openPanel.showsResizeIndicator = true
        openPanel.worksWhenModal = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.resolvesAliases = true
        openPanel.title = windowTitle
        openPanel.allowedFileTypes = fileTypeArray
        
        openPanel.beginSheetModalForWindow(NSApplication.sharedApplication().keyWindow!, completionHandler: { (result) -> Void in
            if result == NSModalResponseOK{
                var selection = openPanel.URL
                let  path = selection!.absoluteString
                completion(path: path!)
            }
        })
    }
    
}

extension NSTextField{
    
    public override func performKeyEquivalent(event: NSEvent) -> Bool {
        var commandKey = NSEventModifierFlags.CommandKeyMask.rawValue
        var commandShiftKey = NSEventModifierFlags.CommandKeyMask.rawValue | NSEventModifierFlags.ShiftKeyMask.rawValue
        if event.type == NSEventType.KeyDown {
            if (event.modifierFlags.rawValue & NSEventModifierFlags.DeviceIndependentModifierFlagsMask.rawValue) == commandKey {
                switch event.charactersIgnoringModifiers! {
                case "x":
                    if NSApp.sendAction(Selector("cut:"), to:nil, from:self) { return true }
                case "c":
                    if NSApp.sendAction(Selector("copy:"), to:nil, from:self) { return true }
                case "v":
                    if NSApp.sendAction(Selector("paste:"), to:nil, from:self) { return true }
                case "z":
                    if NSApp.sendAction(Selector("undo:"), to:nil, from:self) { return true }
                case "a":
                    if NSApp.sendAction(Selector("selectAll:"), to:nil, from:self) { return true }
                default:
                    break
                }
            }
            else if (event.modifierFlags.rawValue & NSEventModifierFlags.DeviceIndependentModifierFlagsMask.rawValue) == commandShiftKey {
                if event.charactersIgnoringModifiers == "Z" {
                    if NSApp.sendAction(Selector("redo:"), to:nil, from:self) { return true }
                }
            }
        }
        return super.performKeyEquivalent(event)
    }
}

