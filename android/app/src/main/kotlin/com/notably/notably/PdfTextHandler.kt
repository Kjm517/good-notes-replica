package com.notably.notably

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.interactive.action.PDActionGoTo
import com.tom_roush.pdfbox.pdmodel.interactive.documentnavigation.destination.PDPageDestination
import com.tom_roush.pdfbox.pdmodel.interactive.documentnavigation.outline.PDOutlineItem
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/// Opens a PDF from disk with PdfBox (temp-file buffered) and returns one
/// page of text at a time so a 150 MB textbook never enters the Dart heap.
class PdfTextHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val documents = ConcurrentHashMap<String, PDDocument>()
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var loaded = false

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                when (call.method) {
                    "open" -> {
                        ensureLoaded()
                        val path = call.argument<String>("path")
                            ?: throw IllegalArgumentException("path required")
                        val id = UUID.randomUUID().toString()
                        val file = File(path)
                        val doc = try {
                            PDDocument.load(file, MemoryUsageSetting.setupTempFileOnly())
                        } catch (_: Exception) {
                            PDDocument.load(file)
                        }
                        documents[id] = doc
                        succeed(result, id)
                    }
                    "extractPage" -> {
                        val doc = documentOf(call)
                        val pageIndex = (call.argument<Number>("pageIndex") ?: 0).toInt()
                        val pageNumber = pageIndex + 1
                        if (pageNumber < 1 || pageNumber > doc.numberOfPages) {
                            succeed(result, "")
                            return@execute
                        }
                        val stripper = PDFTextStripper()
                        stripper.sortByPosition = true
                        stripper.startPage = pageNumber
                        stripper.endPage = pageNumber
                        succeed(result, stripper.getText(doc) ?: "")
                    }
                    "outline" -> succeed(result, readOutline(documentOf(call)))
                    "close" -> {
                        val id = call.argument<String>("id")
                        documents.remove(id)?.close()
                        succeed(result, null)
                    }
                    else -> main.post { result.notImplemented() }
                }
            } catch (e: Exception) {
                main.post {
                    result.error("pdf_text", e.message, null)
                }
            }
        }
    }

    private fun ensureLoaded() {
        if (loaded) return
        PDFBoxResourceLoader.init(context)
        loaded = true
    }

    private fun documentOf(call: MethodCall): PDDocument {
        val id = call.argument<String>("id")
            ?: throw IllegalArgumentException("id required")
        return documents[id] ?: throw IllegalStateException("PDF session closed")
    }

    private fun readOutline(doc: PDDocument): List<Map<String, Any>> {
        val root = doc.documentCatalog.documentOutline ?: return emptyList()
        val entries = mutableListOf<Map<String, Any>>()
        fun walk(item: PDOutlineItem?, depth: Int) {
            var current = item
            while (current != null) {
                val title = current.title?.trim().orEmpty()
                val pageIndex = pageIndexOf(doc, current)
                if (title.isNotEmpty() && pageIndex >= 0) {
                    entries.add(mapOf("t" to title, "p" to pageIndex, "d" to depth))
                }
                walk(current.firstChild, depth + 1)
                current = current.nextSibling
            }
        }
        walk(root.firstChild, 0)
        return entries
    }

    private fun pageIndexOf(doc: PDDocument, item: PDOutlineItem): Int {
        try {
            val page = item.findDestinationPage(doc)
            if (page != null) {
                val idx = doc.pages.indexOf(page)
                if (idx >= 0) return idx
            }
        } catch (_: Exception) {
        }
        try {
            val dest = when (val action = item.action) {
                is PDActionGoTo -> action.destination
                else -> item.destination
            }
            if (dest is PDPageDestination) {
                dest.page?.let { page ->
                    val idx = doc.pages.indexOf(page)
                    if (idx >= 0) return idx
                }
                if (dest.pageNumber >= 0) return dest.pageNumber
            }
        } catch (_: Exception) {
        }
        return -1
    }

    private fun succeed(result: MethodChannel.Result, value: Any?) {
        main.post { result.success(value) }
    }

    companion object {
        const val CHANNEL = "notably/pdf_text"

        fun register(context: Context, messenger: BinaryMessenger) {
            PdfTextHandler(context.applicationContext, messenger)
        }
    }
}
