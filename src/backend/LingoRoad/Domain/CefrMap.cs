namespace LingoRoad.Domain;

public static class CefrMap
{
    public static string FromTheta(double theta) => theta switch
    {
        < -1.5 => "A1", < -0.5 => "A2", < 0.5 => "B1",
        < 1.5 => "B2", < 2.25 => "C1", _ => "C2"
    };

    public static int Rank(string cefr) =>
        Array.IndexOf(["A1", "A2", "B1", "B2", "C1", "C2"], cefr);
}
