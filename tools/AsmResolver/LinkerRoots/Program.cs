using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System.Xml.Linq;

// Constants disappear from compiled IL. Collect their actual bound symbols from
// the same C# sources as the runtime/API root, including aliases and using static.
var libraryDirectory = args[0];
var referenceDirectory = args[1];
var output = args[2];
var trees = args.Skip(3).Select(path => CSharpSyntaxTree.ParseText(File.ReadAllText(path), path: path)).ToArray();
var references = Directory.GetFiles(referenceDirectory, "*.dll")
    .Concat(Directory.GetFiles(libraryDirectory, "AsmResolver*.dll"))
    .Select(path => MetadataReference.CreateFromFile(path));
var compilation = CSharpCompilation.Create("LinkerRootAnalysis", trees, references,
    new CSharpCompilationOptions(OutputKind.ConsoleApplication, allowUnsafe: true));
var errors = compilation.GetDiagnostics().Where(d => d.Severity == DiagnosticSeverity.Error).ToArray();
if (errors.Length != 0) throw new InvalidOperationException(string.Join(Environment.NewLine, errors.Select(d => d.ToString())));
var fields = new HashSet<IFieldSymbol>(SymbolEqualityComparer.Default);
foreach (var tree in trees)
{
    var model = compilation.GetSemanticModel(tree);
    foreach (var node in tree.GetRoot().DescendantNodes().OfType<ExpressionSyntax>())
        if (model.GetSymbolInfo(node).Symbol is IFieldSymbol { IsConst: true } field &&
            field.ContainingAssembly.Name.StartsWith("AsmResolver", StringComparison.Ordinal))
            fields.Add(field);
}
string TypeName(INamedTypeSymbol type) => type.ContainingType is not null
    ? TypeName(type.ContainingType) + "/" + type.MetadataName
    : type.ContainingNamespace.ToDisplayString() + "." + type.MetadataName;
var linker = new XElement("linker", fields.OrderBy(f => f.ContainingAssembly.Name).ThenBy(f => TypeName(f.ContainingType)).ThenBy(f => f.MetadataName)
    .GroupBy(f => f.ContainingAssembly.Name).Select(assembly =>
        new XElement("assembly", new XAttribute("fullname", assembly.Key),
            assembly.GroupBy(f => TypeName(f.ContainingType)).Select(type =>
                new XElement("type", new XAttribute("fullname", type.Key), new XAttribute("preserve", "nothing"),
                    type.Select(field => new XElement("field", new XAttribute("name", field.MetadataName))))))));
new XDocument(linker).Save(output);
Console.WriteLine($"Explicit constant roots: {fields.Count}");
