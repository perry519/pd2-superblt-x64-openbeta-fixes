import "base/native" for Logger, IO, XML
import "base/private/xml_loader" for Tweaker

class BaseTweaker {
	static tweak(name, ext, text) {
		if(Tweaker.tweaks(name, ext)) {
			Logger.log("XML-Tweaking Bundle File %(name).%(ext)")
			var xml = XML.new(text)
			Tweaker.tweak_xml(name, ext, xml)
			text = xml.string
			xml.delete()
		}
		return text
	}
}
