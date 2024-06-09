// Adapted from: https://gist.github.com/aarondandy/aaa622afeeb0cb86b0d4efe697c23be5
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Threading.Tasks;
using WeCantSpell.Hunspell;

namespace HunspellWordForms;

public class WordForms
{
    public class WordFormsObj
    {
        public HashSet<string> PFX;
        public HashSet<string> SFX;
        public HashSet<string> Cross;

        public WordFormsObj(HashSet<string> p, HashSet<string> s, HashSet<string> c)
        {
            this.PFX   = p;
            this.SFX   = s;
            this.Cross = c;
        }

        public bool IsEmpty()
        {
            if (this.PFX.Count == 0 & this.SFX.Count == 0 & this.Cross.Count == 0)
            {
                return true;
            }

            else return false;
        }
    }

    private class Result
    {
        public bool Successful { get; set; }
        public string WordWithAffix { get; set; }
    }

    public class UnmunchedObj
    {
        public string Key;
        public WordFormsObj Forms;

        public UnmunchedObj(string k, WordFormsObj v)
        {
            this.Key   = k;
            this.Forms = v;
        }
    }

    private WordList dict;
    private AffixEntryOptions flag = AffixEntryOptions.CrossProduct;

    public WordForms(string path)
    {
        this.dict = WordList.CreateFromFiles(path);
    }

    private WordForms(){}

    public async static Task<WordForms> CreateAsync(Stream dicStream, Stream affStream)
    {
        WordForms wordForms = new();
        wordForms.dict = await WordList.CreateFromStreamsAsync(dicStream, affStream);
        return wordForms;
    }

    private bool AllowCross(AffixEntryOptions value)
    {
        return (value & this.flag) == this.flag;
    }

    private Result TryAppend(PrefixEntry prefix, string word)
    {
        Result res = new Result();
        if (prefix.Conditions.IsStartingMatch(word.AsSpan()) && word.StartsWith(prefix.Strip))
        {
            res.Successful = true;
            res.WordWithAffix = prefix.Append + word.Substring(prefix.Strip.Length);
            return res;
        }
        else
        {
            res.Successful = false;
            return res;
        }
    }

    private Result TryAppend(SuffixEntry suffix, string word)
    {
        Result res = new Result();
        if (suffix.Conditions.IsEndingMatch(word.AsSpan()) && word.EndsWith(suffix.Strip))
        {
            res.Successful = true;
            res.WordWithAffix = word.Substring(0, word.Length - suffix.Strip.Length) + suffix.Append;
            return res;
        }
        else
        {
            res.Successful = false;
            return res;
        }
    }

    public WordFormsObj GetWordForms(string word, bool NoPFX = false, bool NoSFX = false, bool NoCross = false)
    {
        List<AffixGroup<PrefixEntry>> AllPrefixes = new List<AffixGroup<PrefixEntry>>();
        List<AffixGroup<SuffixEntry>> AllSuffixes = new List<AffixGroup<SuffixEntry>>();
        HashSet<string> wp = new HashSet<string>();
        HashSet<string> ws = new HashSet<string>();
        HashSet<string> wc = new HashSet<string>();

        try
        {
            var item = this.dict[word];
            foreach (var p in this.dict.Affix.Prefixes)
            {
                foreach(var i in item)
                {
                    if (i.ContainsFlag(p.AFlag))
                    {
                        AllPrefixes.Add(p);
                    }
                }
            }
            foreach (var s in this.dict.Affix.Suffixes)
            {
                foreach(var i in item)
                {
                    if (i.ContainsFlag(s.AFlag))
                    {
                        AllSuffixes.Add(s);
                    }
                }
            }
        }
        catch (System.Exception)
        {

        }

        if (!NoPFX)
        {
            foreach (var prefixEntry in AllPrefixes.SelectMany(p => p.Entries))
            {
                Result _out = TryAppend(prefixEntry, word);
                if (_out.Successful)
                {
                    wp.Add(_out.WordWithAffix);
                }
            }
        }

        if (!NoSFX)
        {
            foreach (var suffixEntry in AllSuffixes.SelectMany(p => p.Entries))
            {
                Result _out = TryAppend(suffixEntry, word);
                if (_out.Successful)
                {
                    ws.Add(_out.WordWithAffix);
                }
            }
        }

        if (!NoCross)
        {
            foreach (var prefixEntry in AllPrefixes.Where(p => AllowCross(p.Options)).SelectMany(p => p.Entries))
            {
                Result withPrefix = TryAppend(prefixEntry, word);
                if (withPrefix.Successful)
                {
                    foreach (var suffixEntry in AllSuffixes.Where(p => AllowCross(p.Options)).SelectMany(p => p.Entries))
                    {
                        Result crossOut = TryAppend(suffixEntry, withPrefix.WordWithAffix);
                        if (crossOut.Successful)
                        {
                            wc.Add(crossOut.WordWithAffix);
                        }
                    }
                }
            }
        }
        WordFormsObj res = new WordFormsObj(wp, ws, wc);
        return res;
    }

    public IEnumerable<UnmunchedObj> Unmunch(bool NoPFX = false, bool NoSFX = false, bool NoCross = false)
    {
        List<string> allWords = this.dict.RootWords.ToList();
        allWords.Sort();
        foreach (var w in allWords)
        {
            WordFormsObj forms = GetWordForms(w, NoPFX:NoPFX, NoSFX:NoSFX, NoCross:NoCross);
            if (!forms.IsEmpty())
            {
                UnmunchedObj keyForms = new UnmunchedObj(w, forms);
                yield return keyForms;
            }
        }
    }

    public void SerializeToJson(string OutFileName, bool Indented = true, bool NoPFX = false, bool NoSFX = false, bool NoCross = false)
    {
        string fileName = $"{OutFileName}.json";
        using FileStream createStream = File.Create(fileName);
        var options = new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            Indented = Indented,
        };
        using Utf8JsonWriter writer = new Utf8JsonWriter(createStream, options);
        // https://www.newtonsoft.com/json/help/html/Performance.htm#ManuallySerialize
        writer.WriteStartArray();
        foreach (var it in Unmunch(NoPFX:NoPFX, NoSFX:NoSFX, NoCross:NoCross))
        {
            writer.WriteStartObject();
            writer.WritePropertyName(it.Key);
            writer.WriteStartObject();
            // PFX
            writer.WritePropertyName(nameof(it.Forms.PFX));
            writer.WriteStartArray();
            foreach (var pfx in it.Forms.PFX)
            {
                writer.WriteStringValue(pfx);
            }
            writer.WriteEndArray();
            // SFX
            writer.WritePropertyName(nameof(it.Forms.SFX));
            writer.WriteStartArray();
            foreach (var sfx in it.Forms.SFX)
            {
                writer.WriteStringValue(sfx);
            }
            writer.WriteEndArray();
            // Cross
            writer.WritePropertyName(nameof(it.Forms.Cross));
            writer.WriteStartArray();
            foreach (var cross in it.Forms.Cross)
            {
                writer.WriteStringValue(cross);
            }
            writer.WriteEndArray();

            writer.WriteEndObject();
            writer.WriteEndObject();
            writer.Flush();
        }
        writer.WriteEndArray();

        writer.Dispose();
        createStream.Dispose();
    }
}