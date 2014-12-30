// Copyright (c) 2014 Intel Corporation. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

public class XWalkExtensionFactory {
    private struct XWalkExtensionProvider {
        let bundle: NSBundle
        let className: String
    }
    private var extensions: Dictionary<String, XWalkExtensionProvider> = [:]
    private class var singleton : XWalkExtensionFactory {
        struct single {
            static let instance : XWalkExtensionFactory = XWalkExtensionFactory(path: nil)
        }
        return single.instance
    }

    private init() {
        register("Extension.loader",  cls: XWalkExtensionLoader.self)
    }
    private convenience init(path: String?) {
        self.init()
        if let dir = path ?? NSBundle.mainBundle().privateFrameworksPath {
            self.scan(dir)
        }
    }

    private func scan(path: String) -> Bool {
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(path) == true {
            for i in fm.contentsOfDirectoryAtPath(path, error: nil)! {
                let name = i as String
                if name.pathExtension == "framework" {
                    let bundlePath = path.stringByAppendingPathComponent(name)
                    if let bundle = NSBundle(path: bundlePath) {
                        scanBundle(bundle)
                    }
                }
            }
            return true
        }
        return false
    }

    private func scanBundle(bundle: NSBundle) -> Bool {
        if let info = bundle.objectForInfoDictionaryKey("XWalkExtensions") as? NSDictionary {
            let e = info.keyEnumerator()
            while let name = e.nextObject() as? String {
                if let className = info[name] as? String {
                    if extensions[name] == nil {
                        extensions[name] = XWalkExtensionProvider(bundle: bundle, className: className)
                    } else {
                        println("WARNING: duplicated extension name '\(name)'")
                    }
                } else {
                    println("WARNING: bad class name '\(info[name])'")
                }
            }
        } else {
            return false
        }
        return true
    }

    private func register(name: String, cls: AnyClass) -> Bool {
        if extensions[name] == nil {
            let bundle = NSBundle(forClass: cls)
            var className = NSStringFromClass(cls)
            className = className.pathExtension.isEmpty ? className : className.pathExtension
            extensions[name] = XWalkExtensionProvider(bundle: bundle, className: className)
            return true
        }
        return false
    }

    private func createExtension(name: String, parameter: AnyObject? = nil) -> AnyObject? {
        if let src = extensions[name] {
            // Load bundle
            if !src.bundle.loaded {
                var error : NSErrorPointer = nil
                if !src.bundle.loadAndReturnError(error) {
                    println("ERROR: Can't load bundle '\(src.bundle.bundlePath)'")
                    return nil
                }
            }

            var className = ""
            if let type: AnyClass = src.bundle.classNamed(src.className) {
                // FIXME: Never reach here because the bundle in build directory was loaded in simulator.
                className = NSStringFromClass(type)
            } else {
                // FIXME: workaround the problem
                className = (src.bundle.executablePath?.lastPathComponent)! + "." + src.className
                //println("ERROR: Class '\(src.className)' not found in bundle '\(src.bundle.bundlePath)")
                //return nil
            }

            let inv = Invocation(name: className)
            if parameter != nil {
                inv.appendArgument("param", value: parameter!)
            }
            if let ext: AnyObject = inv.construct() {
                return ext
            }
            println("ERROR: Can't create extension '\(name)'")
        } else {
            println("ERROR: Extension '\(name)' not found")
        }
        return nil
    }

    public class func register(name: String, cls: AnyClass) -> Bool {
        return XWalkExtensionFactory.singleton.register(name, cls: cls)
    }
    public class func createExtension(name: String, parameter: AnyObject? = nil) -> AnyObject? {
        return XWalkExtensionFactory.singleton.createExtension(name, parameter: parameter)
    }
}
