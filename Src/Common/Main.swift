//
//  Main.swift
//  MKHSequence
//
//  Created by Maxim Khatskevich on 11/26/15.
//  Copyright © 2015 Maxim Khatskevich. All rights reserved.
//

import UIKit

//===

public
class Sequence
{
    // MARK: Properties - Private
    
    private
    var name: String?
    
    private
    var tasks: [Task] = []
    
    private
    var onComplete: CompletionHandler?
    
    private
    var onFailure: FailureHandler?
    
    private
    var isCancelled: Bool // calculated helper property
    {
        return status == .Cancelled
    }
    
    private
    var targetTaskIndex = 0
    
    // MARK: Nested types and aliases
    
    public
    typealias Task = (previousResult: Any?) -> Any?
    
    public
    typealias CompletionHandler = (previousResult: Any?) -> Void
    
    public
    typealias FailureHandler = (error: NSError) -> Void
    
    // MARK: Properties - Public
    
    public
    static
    var defaultTargetQueue = NSOperationQueue()
    
    public
    var targetQueue: NSOperationQueue!
    
    public
    enum Status: String
    {
        case
            Pending,
            Processing,
            Failed,
            Completed,
            Cancelled
    }
    
    public private(set)
    var status: Status = .Pending
    
    // MARK: Init
    
    public
    init(name: String? = nil)
    {
        self.name = name
        
        //===
        
        targetQueue = Sequence.defaultTargetQueue
    }
    
    // MARK: Methods - Private
    
    private
    func shouldProceed() -> Bool
    {
        return (targetTaskIndex < self.tasks.count)
    }
    
    private
    func executeNext(previousResult: Any? = nil)
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if
            shouldProceed()
        {
            // regular block
            
            let task = tasks[targetTaskIndex]
            
            //===
            
            targetQueue
                .addOperationWithBlock({ () -> Void in
                    
                    let result = task(previousResult: previousResult)
                    
                    //===
                    
                    NSOperationQueue.mainQueue()
                        .addOperationWithBlock({ () -> Void in
                            
                            if !self.isCancelled
                            {
                                if let error = result as? NSError
                                {
                                    // the task that has been just executed,
                                    // indicated failure by returning NSError,
                                    // lets report error and stop execution
                                    
                                    self.reportFailure(error)
                                }
                                else
                                {
                                    // everything seems to be good,
                                    // lets continue execution
                                    
                                    self.proceed(result)
                                }
                            }
                        })
                })
        }
        else
        {
            executeCompletion(previousResult)
        }
    }
    
    private
    func reportFailure(error: NSError)
    {
        status = .Failed
        
        //===
        
        if let failureHandler = self.onFailure
        {
            failureHandler(error: error);
        }
    }
    
    private
    func proceed(previousResult: Any? = nil)
    {
        targetTaskIndex += 1
        
        //===
        
        executeNext(previousResult)
    }
    
    private
    func executeCompletion(lastResult: Any? = nil)
    {
        status = .Completed
        
        //===
        
        if
            let completionHandler = self.onComplete
        {
            completionHandler(previousResult: lastResult);
        }
    }
    
    private
    func reset() -> Bool
    {
        var result = false
        
        //===
        
        switch status
        {
            case .Failed, .Completed, .Cancelled:
                
                targetTaskIndex = 0
                status = .Pending
                
                //===
                
                result = true
                
            default:
                break // ignore
        }
        
        //===
        
        return result
    }
    
    // MARK: Methods - Public
    
    public
    func add(task: Task) -> Self
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if status == .Pending
        {
            tasks.append(task)
        }
        
        //===
        
        return self
    }
    
    public
    func onFailure(failureHandler: FailureHandler) -> Self
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if status == .Pending
        {
            onFailure = failureHandler
        }
        
        //===
        
        return self
    }
    
    public
    func finally(completionHandler: CompletionHandler) -> Self
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if status == .Pending
        {
            onComplete = completionHandler
            
            //===
            
            start()
        }
        
        //===
        
        return self
    }
    
    public
    func start() -> Self
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if status == .Pending
        {
            status = .Processing
            
            //===
            
            executeNext()
        }
        
        //===
        
        return self
    }
    
    public
    func cancel()
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        switch status
        {
            case .Pending, .Processing:
                status = .Cancelled
            
            default:
                break // ignore
        }
    }
    
    public
    func executeAgain() // (after: NSTimeInterval = 0)
    {
        // NOTE: this mehtod is supposed to be called on main queue
        
        //===
        
        if reset()
        {
            start()
        }
    }
}