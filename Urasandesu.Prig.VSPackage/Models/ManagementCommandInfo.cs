﻿/* 
 * File: ManagementCommandInfo.cs
 * 
 * Author: Akira Sugiura (urasandesu@gmail.com)
 * 
 * 
 * Copyright (c) 2015 Akira Sugiura
 *  
 *  This software is MIT License.
 *  
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */



using EnvDTE;
using System;

namespace Urasandesu.Prig.VSPackage.Models
{
    class ManagementCommandInfo
    {
        public ManagementCommandInfo(string command)
        {
            if (string.IsNullOrEmpty(command))
                throw new ArgumentNullException("command");

            Command = command;
        }

        public ManagementCommandInfo(string command, Project targetProject)
        {
            if (string.IsNullOrEmpty(command))
                throw new ArgumentNullException("command");

            if (targetProject == null)
                throw new ArgumentNullException("targetProject");

            Command = command;
            TargetProject = targetProject;
        }

        public string Command { get; private set; }
        public Project TargetProject { get; private set; }

        public event Action CommandExecuting;
        public event Action CommandExecuted;

        protected internal virtual void OnCommandExecuting()
        {
            var handler = CommandExecuting;
            if (handler == null)
                return;

            handler();
        }

        protected internal virtual void OnCommandExecuted()
        {
            var handler = CommandExecuted;
            if (handler == null)
                return;

            handler();
        }
    }
}
