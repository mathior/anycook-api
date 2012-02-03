package de.anycook.graph;

import java.util.HashSet;
import java.util.List;

import javax.ws.rs.DefaultValue;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.Response;

import org.apache.commons.lang3.tuple.Pair;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

import anycook.misc.JsonpBuilder;
import anycook.recipe.Recipe;
import anycook.search.Search;

@Path("search")
public class SearchGraph {
//	if(parameter.contains("tags"))
//		this.addTags(data.get("tags").split(","));
//		
//	if(parameter.contains("ingredients"))
//		this.addZutaten(data.get("ingredients").split(","));			
//		
//	if(parameter.contains("terms"))
//		this.addTerms(data.get("terms").split(","));
//	
//	if(parameter.contains("category"))
//		this.setKategorie(data.get("category"));
//	
//	if(parameter.contains("calorie"))
//		this.setKalorien(data.get("calorie"));
//	
//	if(parameter.contains("skill"))
//		this.setSkill(data.get("skill"));
//	
//	if(parameter.contains("user"))
//		this.setUser(data.get("user"));
//	
//	if(parameter.contains("time"))
//		this.setTime(data.get("time"));
	
	@SuppressWarnings("unchecked")
	@GET
	public Response search(@QueryParam("callback") String callback, 
			@QueryParam("tags") StringSet tags,
			@QueryParam("ingredients") StringSet ingredients,
			@QueryParam("terms") StringSet terms,
			@QueryParam("category") String category,
			@QueryParam("calorie") int calorie,
			@QueryParam("skill") int skill,
			@QueryParam("time") String time,
			@DefaultValue("0") @QueryParam("start") int start,
			@DefaultValue("10") @QueryParam("num") int num){
		Search search = new Search();
		if(tags!= null && !tags.isEmpty())
			search.addTags(tags);
		if(ingredients != null && !ingredients.isEmpty())
			search.addZutaten(ingredients);
		if(terms != null && !terms.isEmpty())
			search.addTerms(terms);
		search.setKategorie(category);
		search.setCalorie(calorie);
		search.setSkill(skill);
		search.setTime(time);
		
		Pair<Integer, List<String>> resultPair = search.search(start, num);
		JSONObject json = new JSONObject();
		JSONArray recipes = new JSONArray();
		List<String> results = resultPair.getRight();
		for(String result : results){
			recipes.add(Recipe.getJSONforSearch(result));
		}
		
		json.put("size", resultPair.getLeft());
		json.put("recipes", recipes);
		
		return Response.ok(JsonpBuilder.build(callback, json)).build();
	}
	
	public static class StringSet extends HashSet<String>{
		/**
		 * 
		 */
		private static final long serialVersionUID = 1L;

		public StringSet(String in) {
			super();
			if(in != null){
				for(String split : in.split(","))
					add(split);
			}
		}
	}
}
