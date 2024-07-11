//
//  AttributedStringGenerator.swift
//  MarkdownKit
//
//  Created by Matthias Zenger on 01/08/2019.
//  Copyright © 2019-2021 Google LLC.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

///
/// `AttributedStringGenerator` provides functionality for converting Markdown blocks into
/// `NSAttributedString` objects that are used in macOS and iOS for displaying rich text.
/// The implementation is extensible allowing subclasses of `AttributedStringGenerator` to
/// override how individual Markdown structures are converted into attributed strings.
///
open class AttributedStringGenerator {
    
    /// Customized html generator to work around limitations of the current HTML to
    /// `NSAttributedString` conversion logic provided by the operating system.
    open class InternalHtmlGenerator: HtmlGenerator {
        var outer: AttributedStringGenerator?
        
        public init(outer: AttributedStringGenerator) {
            self.outer = outer
        }
        
        open override func generate(block: Block, tight: Bool = false) -> String {
            switch block {
            case .list(_, _, _):
                let listHtml = super.generate(block: block, tight: tight)
                print("listHtml: \(super.generate(block: block, tight: tight)), tight: \(tight)")
                return listHtml
            case .indentedCode(_),
                    .fencedCode(_, _):
                return "<table style=\"width: 100%; margin-bottom: 3px;\"><tbody><tr>" +
                "<td class=\"codebox\">" +
                super.generate(block: block, tight: tight) +
                "</td></tr></tbody></table><p style=\"margin: 0;\" />\n"
            case .blockquote(let blocks):
                return "<table class=\"blockquote\"><tbody><tr>" +
                "<td class=\"quote\" /><td style=\"width: 0.5em;\" /><td>\n" +
                self.generate(blocks: blocks) +
                "</td></tr><tr style=\"height: 0;\"><td /><td /><td /></tr></tbody></table>\n"
            case .thematicBreak:
                return "<table class=\"thematic\" style=\"width: 100%;\"><tbody class=\"thematic\">" +
                "<tr class=\"thematic\"><td class=\"thematic\"></td></tr></tbody></table>"
            case .table(let header, let align, let rows):
                var tagsuffix: [String] = []
                for a in align {
                    switch a {
                    case .undefined:
                        tagsuffix.append(">")
                    case .left:
                        tagsuffix.append(" align=\"left\">")
                    case .right:
                        tagsuffix.append(" align=\"right\">")
                    case .center:
                        tagsuffix.append(" align=\"center\">")
                    }
                }
                var html = "<table class=\"main\"" +
                "cellpadding=\"\(self.outer?.tableCellPadding ?? 2)\"><thead class=\"main\"><tr class=\"main\">\n"
                var i = 0
                for head in header {
                    html += "<th class=\"main\" \(tagsuffix[i])\(self.generate(text: head))&nbsp;</th>"
                    i += 1
                }
                html += "\n</tr></thead><tbody class=\"main\">\n"
                for row in rows {
                    html += "<tr class=\"main\">"
                    i = 0
                    for cell in row {
                        html += "<td  class=\"main\" \(tagsuffix[i])\(self.generate(text: cell))&nbsp;</td>"
                        i += 1
                    }
                    html += "</tr>\n"
                }
                html += "</tbody></table><p style=\"margin: 0;\" />\n"
                return html
            case .definitionList(let defs):
                var html = "<dl>\n"
                for def in defs {
                    html += "<dt>" + self.generate(text: def.item) + "</dt>\n"
                    for descr in def.descriptions {
                        if case .listItem(_, _, let blocks) = descr {
                            html += "<dd>" + self.generate(blocks: blocks) + "</dd>\n"
                        }
                    }
                }
                html += "</dl>\n"
                return html
            case .custom(let customBlock):
                return customBlock.generateHtml(via: self, and: self.outer, tight: tight)
            default:
                return super.generate(block: block, tight: tight)
            }
        }
        
        open override func generate(textFragment fragment: TextFragment) -> String {
            switch fragment {
            case .image(let text, let uri, let title):
                let titleAttr = title == nil ? "" : " title=\"\(title!)\""
                if let uriStr = uri {
                    let url = URL(string: uriStr)
                    if (url?.scheme == nil) || (url?.isFileURL ?? false),
                       let baseUrl = self.outer?.imageBaseUrl {
                        let url = URL(fileURLWithPath: uriStr, relativeTo: baseUrl)
                        if url.isFileURL {
                            return "<a href=\"\(url.absoluteString)\" alt=\"\(text.rawDescription)\"\(titleAttr)/>"
                        }
                    }
                    return "<a href=\"\(uriStr)\">\(text.rawDescription.isEmpty ? titleAttr:text.rawDescription)</a>"
                } else {
                    return self.generate(text: text)
                }
            case .custom(let customTextFragment):
                return customTextFragment.generateHtml(via: self, and: self.outer)
            default:
                return super.generate(textFragment: fragment)
            }
        }
    }
    
    /// Default `AttributedStringGenerator` implementation.
    public static let standard: AttributedStringGenerator = AttributedStringGenerator()
    
    /// The base font size.
    public let fontSize: Float
    
    /// The base font family.
    public let fontFamily: String
    
    /// The base font color.
    public let fontColor: String
    
    /// The code font size.
    public let codeFontSize: Float
    
    /// The code font family.
    public let codeFontFamily: String
    
    /// The code font color.
    public let codeFontColor: String
    
    /// The code block font size.
    public let codeBlockFontSize: Float
    
    /// The code block font color.
    public let codeBlockFontColor: String
    
    /// The code block background color.
    public let codeBlockBackground: String
    
    /// The border color (used for code blocks and for thematic breaks).
    public let borderColor: String
    
    /// The blockquote color.
    public let blockquoteColor: String
    
    /// The color of H1 headers.
    public let h1Color: String
    
    /// The color of H2 headers.
    public let h2Color: String
    
    /// The color of H3 headers.
    public let h3Color: String
    
    /// The color of H4 headers.
    public let h4Color: String
    
    /// The maximum width of an image
    public let maxImageWidth: String?
    
    /// The maximum height of an image
    public let maxImageHeight: String?
    
    /// Custom CSS style
    public let customStyle: String
    
    /// If provided, this URL is used as a base URL for relative image links
    public let imageBaseUrl: URL?
    
    /// Responsible for styling the main table with actual rows and columns
    public let tableBorderWidth: Float
    public let tableBorderStyle: String
    public let tableBorderColor: String
    public let tableHeaderFontSize: Float
    public let tableHeaderFontColor: String
    public let tableHeaderBackgroundColor: String
    public let tableEvenRowFontSize: Float
    public let tableEvenRowFontColor: String
    public let tableEvenRowBackgroundColor: String
    public let tableOddRowFontSize: Float
    public let tableOddRowFontColor: String
    public let tableOddRowBackgroundColor: String
    public let tableEvenDataFontSize: Float
    public let tableEvenDataFontColor: String
    public let tableEvenDataBackgroundColor: String
    public let tableOddDataFontSize: Float
    public let tableOddDataFontColor: String
    public let tableOddDataBackgroundColor: String
    
    ///Responsible for thematic break styling
    public let thematicBorderWidth: Float
    public let thematicBorderStyle: String
    public let thematicBorderColor: String
    
    /// Constructor providing customization options for the generated `NSAttributedString` markup.
    public init(fontSize: Float = 14.0,
                fontFamily: String = "\"Times New Roman\",Times,serif",
                fontColor: String = mdDefaultColor,
                codeFontSize: Float = 13.0,
                codeFontFamily: String =
                "\"Consolas\",\"Andale Mono\",\"Courier New\",Courier,monospace",
                codeFontColor: String = mdDefaultColor,
                codeBlockFontSize: Float = 12.0,
                codeBlockFontColor: String = mdDefaultColor,
                codeBlockBackground: String = mdDefaultBackgroundColor,
                borderColor: String = "#bbb",
                blockquoteColor: String = "#99c",
                h1Color: String = mdDefaultColor,
                h2Color: String = mdDefaultColor,
                h3Color: String = mdDefaultColor,
                h4Color: String = mdDefaultColor,
                maxImageWidth: String? = nil,
                maxImageHeight: String? = nil,
                customStyle: String = "",
                imageBaseUrl: URL? = nil,
                
                tableBorderWidth: Float = 0.1,
                tableBorderStyle: String = "solid",
                tableBorderColor: String = "black",
                tableHeaderFontSize: Float = 15.0,
                tableHeaderFontColor: String = "black",
                tableHeaderBackgroundColor: String = "#00000000",
                tableEvenRowFontSize: Float = 14.0,
                tableEvenRowFontColor: String = "black",
                tableEvenRowBackgroundColor: String = "#00000030",
                tableOddRowFontSize: Float = 14.0,
                tableOddRowFontColor: String = "black",
                tableOddRowBackgroundColor: String = "#00000000",
                tableEvenDataFontSize: Float = 14.0,
                tableEvenDataFontColor: String = "black",
                tableEvenDataBackgroundColor: String = "",
                tableOddDataFontSize: Float = 14.0,
                tableOddDataFontColor: String = "black",
                tableOddDataBackgroundColor: String = "",
                
                thematicBorderWidth: Float = 1,
                thematicBorderStyle: String = "solid",
                thematicBorderColor: String = "#00000030"
                
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.fontColor = fontColor
        self.codeFontSize = codeFontSize
        self.codeFontFamily = codeFontFamily
        self.codeFontColor = codeFontColor
        self.codeBlockFontSize = codeBlockFontSize
        self.codeBlockFontColor = codeBlockFontColor
        self.codeBlockBackground = codeBlockBackground
        self.borderColor = borderColor
        self.blockquoteColor = blockquoteColor
        self.h1Color = h1Color
        self.h2Color = h2Color
        self.h3Color = h3Color
        self.h4Color = h4Color
        self.maxImageWidth = maxImageWidth
        self.maxImageHeight = maxImageHeight
        self.customStyle = customStyle
        self.imageBaseUrl = imageBaseUrl
        
        self.tableBorderWidth = tableBorderWidth
        self.tableBorderStyle = tableBorderStyle
        self.tableBorderColor = tableBorderColor
        self.tableHeaderFontSize = tableHeaderFontSize
        self.tableHeaderFontColor = tableHeaderFontColor
        self.tableHeaderBackgroundColor = tableHeaderBackgroundColor
        self.tableEvenRowFontSize = tableEvenRowFontSize
        self.tableEvenRowFontColor = tableEvenRowFontColor
        self.tableEvenRowBackgroundColor = tableEvenRowBackgroundColor
        self.tableOddRowFontSize = tableOddRowFontSize
        self.tableOddRowFontColor = tableOddRowFontColor
        self.tableOddRowBackgroundColor = tableOddRowBackgroundColor
        self.tableEvenDataFontSize = tableEvenDataFontSize
        self.tableEvenDataFontColor = tableEvenDataFontColor
        self.tableEvenDataBackgroundColor = tableEvenDataBackgroundColor
        self.tableOddDataFontSize = tableOddDataFontSize
        self.tableOddDataFontColor = tableOddDataFontColor
        self.tableOddDataBackgroundColor = tableOddDataBackgroundColor
        
        self.thematicBorderWidth = thematicBorderWidth
        self.thematicBorderStyle = thematicBorderStyle
        self.thematicBorderColor = thematicBorderColor
    }
    
    /// Generates an attributed string from the given Markdown document
    open func generate(doc: Block) -> NSAttributedString? {
        return self.generateAttributedString(self.htmlGenerator.generate(doc: doc))
    }
    
    /// Generates an attributed string from the given Markdown blocks
    open func generate(block: Block) -> NSAttributedString? {
        return self.generateAttributedString(self.htmlGenerator.generate(block: block))
    }
    
    /// Generates an attributed string from the given Markdown blocks
    open func generate(blocks: Blocks) -> NSAttributedString? {
        return self.generateAttributedString(self.htmlGenerator.generate(blocks: blocks))
    }
    
    private func generateAttributedString(_ htmlBody: String) -> NSAttributedString? {
        let htmlDoc = self.generateHtml(htmlBody)
        let httpData = Data(htmlDoc.utf8)
        return try? NSAttributedString(data: httpData,
                                       options: [.documentType: NSAttributedString.DocumentType.html,
                                                 .characterEncoding: String.Encoding.utf8.rawValue],
                                       documentAttributes: nil)
    }
    
    open var htmlGenerator: HtmlGenerator {
        return InternalHtmlGenerator(outer: self)
    }
    
    open func generateHtml(_ htmlBody: String) -> String {
        return "<html>\n\(self.htmlHead)\n\(self.htmlBody(htmlBody))\n</html>"
    }
    
    open var htmlHead: String {
        return "<head><meta charset=\"utf-8\"/><style type=\"text/css\">\n" +
        self.docStyle +
        "\n</style></head>\n"
    }
    
    open func htmlBody(_ body: String) -> String {
        return "<body>\n\(body)\n</body>"
    }
    
    open var docStyle: String {
        return "body             { \(self.bodyStyle) }\n" +
        "h1               { \(self.h1Style) }\n" +
        "h2               { \(self.h2Style) }\n" +
        "h3               { \(self.h3Style) }\n" +
        "h4               { \(self.h4Style) }\n" +
        "h5               { \(self.h4Style) }\n" +
        "h6               { \(self.h4Style) }\n" +
        "p                { \(self.pStyle) }\n" +
//        "ul               { \(self.ulStyle) }\n" +
//        "ol               { \(self.olStyle) }\n" +
//        "li               { \(self.liStyle) }\n" +
        "table.blockquote { \(self.blockquoteStyle) }\n" +
        
        //main table
        "table.main                  { \(self.tableStyle) }\n" +
        "thead.main th.main          { \(self.tableHeaderStyle) }\n" +
        "tr.main:nth-child(even)     { \(self.tableEvenRowStyle) }\n" +
        "tr.main:nth-child(odd)      { \(self.tableOddRowStyle) }\n" +
        "td.main:nth-child(even)     { \(self.tableEvenDataStyle) }\n" +
        "td.main:nth-child(odd)      { \(self.tableOddDataStyle) }\n" +
        
        "pre              { \(self.preStyle) }\n" +
        "code             { \(self.codeStyle) }\n" +
        "pre code         { \(self.preCodeStyle) }\n" +
        "td.codebox       { \(self.codeBoxStyle) }\n" +
        
        //thematic break table
        "table.thematic   { \(self.thematicBreakTableStyle) }\n" +
        "tbody.thematic   { \(self.thematicBreakTableStyle) }\n" +
        "tr.thematic      { \(self.thematicBreakTableRowStyle) }\n" +
        "td.thematic      { \(self.thematicBreakTableDataStyle) }\n" +
        
        "td.quote         { \(self.quoteStyle) }\n" +
        "img              { \(self.imgStyle) }\n" +
        "dt {\n" +
        "  font-weight: bold;\n" +
        "  margin: 0.6em 0 0.4em 0;\n" +
        "}\n" +
        "dd {\n" +
        "  margin: 0.5em 0 1em 2em;\n" +
        "  padding: 0.5em 0 1em 2em;\n" +
        "}\n" +
        "\(self.customStyle)\n"
    }
    
    open var bodyStyle: String {
        return "font-size: \(self.fontSize)px;" +
        "font-family: \(self.fontFamily);" +
        "color: \(self.fontColor);"
    }
    
    open var h1Style: String {
        return "font-size: \(self.fontSize + 6)px;" +
        "color: \(self.h1Color);" +
        "margin: 0.7em 0 0.5em 0;"
    }
    
    open var h2Style: String {
        return "font-size: \(self.fontSize + 4)px;" +
        "color: \(self.h2Color);" +
        "margin: 0.6em 0 0.4em 0;"
    }
    
    open var h3Style: String {
        return "font-size: \(self.fontSize + 2)px;" +
        "color: \(self.h3Color);" +
        "margin: 0.5em 0 0.3em 0;"
    }
    
    open var h4Style: String {
        return "font-size: \(self.fontSize + 1)px;" +
        "color: \(self.h4Color);" +
        "margin: 0.5em 0 0.3em 0;"
    }
    
    open var pStyle: String {
        return "margin: 0.7em 0;"
    }
    
    open var ulStyle: String {
        return "margin: 0.7em 0;"
    }
    
    open var olStyle: String {
        return "margin: 0.7em 0;"
    }
    
    open var liStyle: String {
        return "margin-left: 0.25em;" +
        "margin-bottom: 0.1em;"
    }
    
    open var preStyle: String {
        return "background: \(self.codeBlockBackground);"
    }
    
    open var codeStyle: String {
        return "font-size: \(self.codeFontSize)px;" +
        "font-family: \(self.codeFontFamily);" +
        "color: \(self.codeFontColor);" +
        "background: \(self.codeBlockBackground);" +
        "border: 1px solid \(self.borderColor);"
    }
    
    open var preCodeStyle: String {
        return "font-size: \(self.codeBlockFontSize)px;" +
        "font-family: \(self.codeFontFamily);" +
        "color: \(self.codeBlockFontColor);"
    }
    
    open var codeBoxStyle: String {
        return "font-size: \(self.codeFontSize)px;" +
        "font-family: \(self.codeFontFamily);" +
        "color: \(self.codeFontColor);" +
        "background: \(self.codeBlockBackground);" +
        "border: 1px solid \(self.borderColor);" +
        "padding: 0.5em;" +
        "width: 100%;"
    }
    
    open var thematicBreakTableStyle: String {
        return "border-collapse: collapse;" +
        "border-top: \(self.thematicBorderWidth)px \(self.thematicBorderStyle) \(self.thematicBorderColor);" +
        "table-layout: fixed;" +
        "width:100%;"
    }
    
    open var thematicBreakTableRowStyle: String {
        return ""
    }
    
    open var thematicBreakTableDataStyle: String {
        return ""
    }
    
    open var blockquoteStyle: String {
        return "width: 100%;" +
        "margin: 0.3em 0;" +
        "font-size: \(self.fontSize)px;"
    }
    
    open var quoteStyle: String {
        return "background: \(self.blockquoteColor);" +
        "width: 0.4em;"
    }
    
    open var imgStyle: String {
        if let maxWidth = self.maxImageWidth {
            if let maxHeight = self.maxImageHeight {
                return "max-width: \(maxWidth) !important;max-height: \(maxHeight) !important;" +
                "width: auto;height: auto;"
            } else {
                return "max-height: 100%;max-width: \(maxWidth) !important;width: auto;height: auto;"
            }
        } else if let maxHeight = self.maxImageHeight {
            return "max-width: 100%;max-height: \(maxHeight) !important;width: auto;height: auto;"
        } else {
            return ""
        }
    }
    
    open var tableStyle: String {
        return "border-collapse: collapse;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);" +
        "padding: 3px;" +
        "font-size: \(self.fontSize)px;" +
        "table-layout: fixed;" +
        "width:100%;"
    }
    
    open var tableHeaderStyle: String {
        "background-color: \(self.tableHeaderBackgroundColor);" +
        "color: \(self.tableHeaderFontColor);" +
        "font-size: \(self.tableHeaderFontSize)px;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);"
    }
    
    open var tableEvenRowStyle: String {
        return "background-color: \(self.tableEvenRowBackgroundColor);" +
        "color: \(self.tableEvenRowFontColor);" +
        "font-size: \(self.tableEvenRowFontSize)px;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);" +
        "table-layout: fixed;" +
        "width:100%;"
    }
    
    open var tableOddRowStyle: String {
        return "background-color: \(self.tableOddRowBackgroundColor);" +
        "color: \(self.tableOddRowFontColor);" +
        "font-size: \(self.tableOddRowFontSize)px;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);" +
//        "display:table;" +
        "table-layout: fixed;" +
        "width:100%;"
    }
    
    open var tableEvenDataStyle: String {
        return "background-color: \(self.tableEvenDataBackgroundColor);" +
        "color: \(self.tableEvenDataFontColor);" +
        "font-size: \(self.tableEvenDataFontSize)px;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);"
    }
    
    open var tableOddDataStyle: String {
        return "background-color: \(self.tableOddDataBackgroundColor);" +
        "color: \(self.tableOddDataFontColor);" +
        "font-size: \(self.tableOddDataFontSize)px;" +
        "border: \(self.tableBorderWidth)px \(self.tableBorderStyle) \(self.tableBorderColor);"
    }
    
    open var tableCellPadding: Int {
        return 2
    }
}

#endif
