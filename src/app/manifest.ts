import type { MetadataRoute } from "next";
export default function manifest(): MetadataRoute.Manifest { return { name:"Golf Tour Live Scoring", short_name:"Golf Tour", description:"Live Ryder Cup-style golf tour scoring.", start_url:"/", display:"standalone", background_color:"#07101f", theme_color:"#07101f", icons:[] }; }
